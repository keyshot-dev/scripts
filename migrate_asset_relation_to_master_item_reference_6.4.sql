-- This script will migrate from an asset relation into a master item reference field.
-- This will remove all existing values for the field first, so if you already have values in the field, they will be lost.
-- Works for DAM 6.4, 6.5.

-- Set these variables
declare @targetMasterItemReferenceFieldItemGuid uniqueidentifier = '';
declare @sourceAssetRelationTypeId int = 0;

-- Script starts here
begin transaction;

-- Verify metafield is a master item reference field
if not exists (select *
               from LegacyService_ItemMetafields imf
                        join LegacyService_Items i on imf.Itemid = i.itemid
               where i.ItemGuid = @targetMasterItemReferenceFieldItemGuid
                 and imf.ItemDatatypeid = 80
                 and imf.Autotranslateoverwriteexisting = 1)
    begin
        throw 51000, 'The specified metafield either does not exist, it is not a MasterItemReference field or it doesn''t have autotranslateoverwritingexisting enabled', 1;
    end


-- Verify that the asset relation type exists
if not exists (select *
               from LegacyService_AssetRelationTypes r
               where r.id = @sourceAssetRelationTypeId)
    begin
        throw 51000, 'The specified asset relation type does not exist.', 1;
    end


delete imv
from LegacyService_ItemMetafieldValues imv
         join LegacyService_ItemMetafieldLabels iml on imv.ItemMetafieldLabelid = iml.ItemMetafieldLabelid
         join LegacyService_ItemMetafields imf on iml.ItemMetafieldid = imf.ItemMetafieldid
         join LegacyService_Items i on imf.ItemId = i.itemid
where i.ItemGuid = @targetMasterItemReferenceFieldItemGuid;

with labels as (select iml.ItemMetafieldLabelid
                from LegacyService_ItemMetafieldLabels iml
                         join LegacyService_ItemMetafields imf on iml.ItemMetafieldid = imf.ItemMetafieldid
                         join LegacyService_Items i on imf.ItemId = i.itemid
                where i.ItemGuid = @targetMasterItemReferenceFieldItemGuid),
     relations as (select primary_asset.ItemId as itemid, secondary_asset.ItemId as ref_itemid
                   from LegacyService_AssetRelations r
                            join LegacyService_Assets primary_asset on r.PrimaryAssetId = primary_asset.assetid
                            join LegacyService_Assets secondary_asset on r.SecondaryAssetId = secondary_asset.assetid
                   where r.AssetRelationTypeId = @sourceAssetRelationTypeId)
insert
into LegacyService_ItemMetafieldValues (ItemMetafieldLabelid, Itemid, RefItemid, Value, DateModified, ValueInt, DataTypeId)
select ItemMetafieldLabelid, itemid, ref_itemid, ref_itemid, getdate(), ref_itemid, 80
from labels,
     relations

commit transaction;

