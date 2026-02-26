-- This script will migrate from an existing master item reference field to asset relations. 
-- Be aware that it will remove any existing relations for the specified relation type.
-- Works for DAM 6.4, 6.5.

-- Set these variables
declare @sourceMasterItemReferenceFieldItemGuid uniqueidentifier = '';
declare @targetAssetRelationTypeId int = 0;
declare @includeReplacedAssets bit = 0;

-- Script starts here
begin transaction;

-- Verify metafield is a master item reference field
if not exists (select *
               from LegacyService_ItemMetafields imf
                        join LegacyService_Items i on imf.ItemId = i.Itemid
               where i.ItemGuid = @sourceMasterItemReferenceFieldItemGuid
                 and imf.ItemDatatypeid = 80
                 and imf.autotranslateoverwriteexisting = 1)
    begin;
        throw 51000, 'The specified metafield either does not exist, it is not a MasterItemReference field or it doesn''t have autotranslateoverwriteexisting enabled', 1;
    end

-- Verify that the target asset relation type exists
if not exists (select *
               from LegacyService_AssetRelationTypes r
               where r.id = @targetAssetRelationTypeId)
    begin;
        throw 51000, 'The specified asset relation type does not exist.', 1;
    end

-- Get the label_id to migrate values from
declare @source_label_id int = (select iml.ItemMetafieldLabelid
                                from LegacyService_ItemMetafieldLabels iml
                                         join LegacyService_ItemMetafields imf
                                              on iml.ItemMetafieldid = imf.ItemMetafieldid
                                         join LegacyService_Items i on imf.ItemId = i.Itemid
                                where i.ItemGuid = @sourceMasterItemReferenceFieldItemGuid
                                  and iml.languageid = 3 -- Always migrate from english
);

declare @asset_relation_multiplicity int = (select multiplicity
                                            from LegacyService_AssetRelationTypes
                                            where id = @targetAssetRelationTypeId);

-- Remove any existing relations for this type to avoid having to deal with duplicates.
delete
from LegacyService_AssetRelations
where AssetRelationTypeId = @targetAssetRelationTypeId;

-- Create the new relations
insert into LegacyService_AssetRelations (PrimaryAssetId, SecondaryAssetId, AssetRelationTypeId, AllowedMultiplicity,
                                          CreatedAt)
select primary_asset.assetid        as primary_asset_id,
       secondary_asset.assetid      as secondary_asset_id,
       @targetAssetRelationTypeId   as asset_relation_type_id,
       @asset_relation_multiplicity as allowed_multiplicity,
       GETDATE()                    as created_at
from LegacyService_ItemMetafieldValues imv
         join LegacyService_Assets primary_asset on imv.itemid = primary_asset.ItemId
         join LegacyService_Assets secondary_asset on imv.RefItemid = secondary_asset.ItemId
where imv.ItemMetafieldLabelid = @source_label_id
  and IIF(@includeReplacedAssets = 1, (1 = 1),
          (primary_asset.ReplacedWith is null and secondary_asset.ReplacedWith is null));

-- Verify that we don't break any asset category constraints -- Primary direction
if exists(select *
          from LegacyService_AssetRelationTypePrimaryAssetCategory
          where AssetRelationTypeId = @targetAssetRelationTypeId)
    begin
        declare @primary_asset_category_ids table
                                            (
                                                asset_category_id int primary key,
                                                recursive         bit
                                            );

        insert into @primary_asset_category_ids
        select AssetCategoryId, recursive
        from LegacyService_AssetRelationTypePrimaryAssetCategory
        where AssetRelationTypeId = @targetAssetRelationTypeId;

        declare @last_count int = 0;

        while @last_count != (select count(*) from @primary_asset_category_ids)
            begin
                -- Do my own shitty recursion because sqlserver doesn't support "union" in recursive CTEs. It only supports "union all", 
                -- which will give duplicates. 
                set @last_count = (select count(*) from @primary_asset_category_ids);

                with child_categories as (select *
                                          from @primary_asset_category_ids prim
                                                   join LegacyService_AssetCategories c
                                                        on prim.asset_category_id = c.ParentCategoryId
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

        declare @invalid_primary_assets table
                                        (
                                            asset_id int primary key
                                        );

        insert into @invalid_primary_assets
        select a.assetid
        from LegacyService_AssetRelations r
                 join LegacyService_Assets a on r.PrimaryAssetId = a.assetid
        where r.AssetRelationTypeId = @targetAssetRelationTypeId
          and not exists (select * from @primary_asset_category_ids i where i.asset_category_id = a.AssetCategoryId);

        if exists(select * from @invalid_primary_assets)
            begin
                -- Invalid primary assets
                select * from @invalid_primary_assets;
                throw 51000, 'The migration would break asset category constraints', 1;
            end
    end


-- Verify that we don't break any asset category constraints -- Secondary direction
if exists(select *
          from LegacyService_AssetRelationTypeSecondaryAssetCategory
          where AssetRelationTypeId = @targetAssetRelationTypeId)
    begin
        declare @secondary_asset_category_ids table
                                              (
                                                  asset_category_id int primary key,
                                                  recursive         bit
                                              );

        insert into @secondary_asset_category_ids
        select AssetCategoryId, recursive
        from LegacyService_AssetRelationTypeSecondaryAssetCategory
        where AssetRelationTypeId = @targetAssetRelationTypeId;

        set @last_count = 0;

        while @last_count != (select count(*) from @secondary_asset_category_ids)
            begin
                -- Do my own shitty recursion because sqlserver doesn't support "union" in recursive CTEs. It only supports "union all", 
                -- which will give duplicates. 
                set @last_count = (select count(*) from @secondary_asset_category_ids);

                with child_categories as (select *
                                          from @secondary_asset_category_ids sec
                                                   join LegacyService_AssetCategories c
                                                        on sec.asset_category_id = c.ParentCategoryId
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

        declare @invalid_secondary_assets table
                                          (
                                              asset_id int primary key
                                          );

        insert into @invalid_secondary_assets
        select a.assetid
        from LegacyService_AssetRelations r
                 join LegacyService_Assets a on r.SecondaryAssetId = a.assetid
        where r.AssetRelationTypeId = @targetAssetRelationTypeId
          and not exists (select *
                          from @secondary_asset_category_ids i
                          where i.asset_category_id = a.AssetCategoryId);

        if exists(select * from @invalid_secondary_assets)
            begin
                select * from @invalid_secondary_assets;
                throw 51000, 'The migration would break asset category constraints.', 1;
            end
    end


commit transaction;




