-- This script will migrate from an existing master item reference field to asset relations. 
-- Be aware that it will remove any existing relations for the specified relation type.
-- Works for DAM 6.3.

-- Set these variables
declare @sourceMasterItemReferenceFieldItemGuid uniqueidentifier = '';
declare @targetAssetRelationTypeId int = 0;

-- Script starts here
begin transaction;

-- Verify metafield is a master item reference field
if not exists (select *
               from item_metafield imf
                        join item i on imf.item_id = i.itemid
               where i.ItemGuid = @sourceMasterItemReferenceFieldItemGuid
                 and imf.item_datatypeid = 80
                 and imf.autotranslateoverwriteexisting = 1)
    begin
        throw 51000, 'The specified metafield either does not exist, it is not a MasterItemReference field or it doesn''t have autotranslateoverwriteexisting enabled', 1;
    end


-- Verify that the target asset relation type exists
if not exists (select *
               from asset_relation_types r
               where r.id = @targetAssetRelationTypeId)
    begin
        throw 51000, 'The specified asset relation type does not exist.', 1;
    end


    
    
    
-- Get the label_id to migrate values from
declare @source_label_id int = (select iml.item_metafield_labelid
                                from item_metafield_label iml
                                         join item_metafield imf on iml.item_metafieldid = imf.item_metafieldid
                                         join item i on imf.item_id = i.itemid
                                where i.ItemGuid = @sourceMasterItemReferenceFieldItemGuid
                                  and iml.languageid = 3 -- Always migrate from english
);

declare @asset_relation_multiplicity int = (select multiplicity
                                            from asset_relation_types
                                            where id = @targetAssetRelationTypeId);


-- Remove any existing relations for this type to avoid having to deal with duplicates.
delete from asset_relations where asset_relation_type_id = @targetAssetRelationTypeId;

-- Create the new relations
insert into asset_relations (primary_asset_id, secondary_asset_id, asset_relation_type_id, allowed_multiplicity)
select primary_asset.assetid        as primary_asset_id,
       secondary_asset.assetid      as secondary_asset_id,
       @targetAssetRelationTypeId   as asset_relation_type_id,
       @asset_relation_multiplicity as allowed_multiplicity
from item_metafield_value imv
         join asset primary_asset on imv.itemid = primary_asset.item_id
         join asset secondary_asset on imv.ref_itemid = secondary_asset.item_id
where imv.item_metafield_labelid = @source_label_id;

-- Verify that we don't break any asset category constraints -- Primary direction
if exists(select * from asset_relation_type_primary_asset_categories where asset_relation_type_id = @targetAssetRelationTypeId)
    begin
        declare @primary_asset_category_ids table(asset_category_id int primary key, recursive bit);
        
        insert into @primary_asset_category_ids
        select asset_category_id, recursive from asset_relation_type_primary_asset_categories where asset_relation_type_id = @targetAssetRelationTypeId;
        
        declare @last_count int = 0;
        
        while @last_count != (select count(*) from @primary_asset_category_ids)
        begin
            -- Do my own shitty recursion because sqlserver doesn't support "union" in recursive CTEs. It only supports "union all", 
            -- which will give duplicates. 
            set @last_count = (select count(*) from @primary_asset_category_ids);
            
            with child_categories as (select *
                                      from @primary_asset_category_ids prim
                                               join asset_category c on prim.asset_category_id = c.parent_category_id
                                      where prim.recursive = 1)
            merge into @primary_asset_category_ids as target
            using child_categories as source
            on target.asset_category_id = source.id
            when not matched then
                insert (asset_category_id, recursive)
                values (source.id, 1)
            when matched then
                update set target.recursive = 1;
        end
        
        declare @invalid_primary_assets table(asset_id int primary key);
        
        insert into @invalid_primary_assets
        select a.assetid from asset_relations r
        join asset a on r.primary_asset_id = a.assetid
        where r.asset_relation_type_id = @targetAssetRelationTypeId and not exists (select * from @primary_asset_category_ids i where i.asset_category_id = a.asset_category_id);
        
        if exists(select * from @invalid_primary_assets)
        begin
            -- Invalid primary assets
            select * from @invalid_primary_assets;
            throw 51000, 'The migration would break asset category constraints', 1;
        end
    end


-- Verify that we don't break any asset category constraints -- Secondary direction
if exists(select * from asset_relation_type_secondary_asset_categories where asset_relation_type_id = @targetAssetRelationTypeId)
    begin
        declare @secondary_asset_category_ids table(asset_category_id int primary key, recursive bit);

        insert into @secondary_asset_category_ids
        select asset_category_id, recursive from asset_relation_type_secondary_asset_categories where asset_relation_type_id = @targetAssetRelationTypeId;

        set @last_count = 0;

        while @last_count != (select count(*) from @secondary_asset_category_ids)
            begin
                -- Do my own shitty recursion because sqlserver doesn't support "union" in recursive CTEs. It only supports "union all", 
                -- which will give duplicates. 
                set @last_count = (select count(*) from @secondary_asset_category_ids);

                with child_categories as (select *
                                          from @secondary_asset_category_ids sec
                                                   join asset_category c on sec.asset_category_id = c.parent_category_id
                                          where sec.recursive = 1)
                    merge into @secondary_asset_category_ids as target
                using child_categories as source
                on target.asset_category_id = source.id
                when not matched then
                    insert (asset_category_id, recursive)
                    values (source.id, 1)
                when matched then
                    update set target.recursive = 1;
            end

        declare @invalid_secondary_assets table(asset_id int primary key);

        insert into @invalid_secondary_assets
        select a.assetid from asset_relations r
                                  join asset a on r.secondary_asset_id = a.assetid
        where r.asset_relation_type_id = @targetAssetRelationTypeId and not exists (select * from @secondary_asset_category_ids i where i.asset_category_id = a.asset_category_id);

        if exists(select * from @invalid_secondary_assets)
            begin
                select * from @invalid_secondary_assets;
                throw 51000, 'The migration would break asset category constraints.', 1;
            end
    end



commit transaction;




