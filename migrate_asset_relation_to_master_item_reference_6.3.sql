-- This script will migrate from an asset relation into a master item reference field.
-- This will remove all existing values for the field first, so if you already have values in the field, they will be lost.
-- Works for DAM 6.3.

-- Set these variables
declare @targetMasterItemReferenceFieldItemGuid uniqueidentifier = '';
declare @sourceAssetRelationTypeId int = 0;

-- Script starts here
begin transaction;

-- Verify metafield is a master item reference field
if not exists (select *
               from item_metafield imf
                        join item i on imf.item_id = i.itemid
               where i.ItemGuid = @targetMasterItemReferenceFieldItemGuid
                 and imf.item_datatypeid = 80
                 and imf.autotranslateoverwriteexisting = 1)
    begin
        throw 51000, 'The specified metafield either does not exist, it is not a MasterItemReference field or it doesn''t have autotranslateoverwritingexisting enabled', 1;
    end


-- Verify that the asset relation type exists
if not exists (select *
               from asset_relation_types r
               where r.id = @sourceAssetRelationTypeId)
    begin
        throw 51000, 'The specified asset relation type does not exist.', 1;
    end


delete imv from item_metafield_value imv
join item_metafield_label iml on imv.item_metafield_labelid = iml.item_metafield_labelid
join item_metafield imf on iml.item_metafieldid = imf.item_metafieldid
join item i on imf.item_id = i.itemid
where i.ItemGuid = @targetMasterItemReferenceFieldItemGuid;

with labels as (select iml.item_metafield_labelid from item_metafield_label iml
                                                           join item_metafield imf on iml.item_metafieldid = imf.item_metafieldid
                                                           join item i on imf.item_id = i.itemid
                where i.ItemGuid = @targetMasterItemReferenceFieldItemGuid

),
     relations as (
         select primary_asset.item_id as itemid, secondary_asset.item_id as ref_itemid from asset_relations r
                                                                                                join asset primary_asset on r.primary_asset_id = primary_asset.assetid
                                                                                                join asset secondary_asset on r.secondary_asset_id = secondary_asset.assetid
         where r.asset_relation_type_id = @sourceAssetRelationTypeId

     )
insert into item_metafield_value (item_metafield_labelid, itemid, ref_itemid, value, DateModified, valueInt, dataTypeId)
select item_metafield_labelid, itemid, ref_itemid, ref_itemid, getdate(), ref_itemid, 80 from labels, relations

commit transaction ;

