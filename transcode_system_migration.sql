/*
This script migrates as much configuration as possible from the old transcode system to the new transcode system.

Assumptions:
	- This script is run against a 5.10 environment
	- No manual changes have been made to any formats after upgrading the targeted environment to 5.10.

Things to be aware of:
	- Since this script changes the configuration of the targeted environment,
	  please ensure that you handle the changes in Configuration Management after having run this script.



If a format doesn't have any conditions specified on when it should be created in the old transcode system
it will be allowed to be created in all cases in the new system. To identify these formats you can use the
following script. The script can be run after the migration too to identify the "bad" formats for cleanup
should that be desired.

```
select mf.media_formatid, mfl.medianame, vf.foldername, vf.folderpath
from (select mf.media_formatid
            from media_format mf
                     left join digizuite_assettype_configs_upload_quality uq on mf.media_formatid = uq.FormatId
            where uq.FormatId is null
            intersect
            select mf.media_formatid
            from media_format mf
                     left join dz_profileformat pf on mf.media_formatid = pf.media_formatid
                     left join dbo.Layoutfolder_Profile_Destination LPD on pf.dz_profileid = LPD.Dz_ProfileId
            where LPD.Layoutfolder_Profile_DestinationId is null

            except
            select mft.identifyMediaFormatId from media_format_type mft
      ) as formats_with_path
         join media_format mf on mf.media_formatid = formats_with_path.media_formatid
         join media_format_language mfl on mf.media_formatid = mfl.media_formatid and mfl.languageid = 3
         left join VirtualFolder vf
                   on mf.foldermedia_formatID = vf.folderid and vf.repositoryid = 16 and vf.languageid = 3
order by foldername asc
```

*/



-- Start transaction to ensure that the migration is atomic.
BEGIN TRANSACTION
BEGIN TRY

SET NOCOUNT ON;

DECLARE @mediaFormatId INT,
    @mediaFormatTypeId INT,
    @name NVARCHAR(255),
    @downloadReplaceMask NVARCHAR(MAX),
    @audioBitrate INT,
    @videoBitrate INT,
    @width INT,
    @height INT,
    @settings NVARCHAR(1024),
    @iccProfile NVARCHAR(512),
    @colorSpaceEnum NVARCHAR(1),
    @extension NVARCHAR(10),
    @details NVARCHAR(MAX),
    @formatId INT,
    @compressionLevel INT,
    @immediatelyGeneratedFor NVARCHAR(MAX),
    @no_security_folder NVARCHAR(MAX),
    @pre_generate_folders NVARCHAR(MAX),
    @assetFilter NVARCHAR(MAX),
    @assetFilter_AssetType NVARCHAR(MAX),
    @assetFilter_ChannelFolder NVARCHAR(MAX);

-- Create temp table with media formats to process.
CREATE TABLE #mediaFormatsToProcess(
    mediaFormatId INT,
    mediaFormatTypeId INT,
    name NVARCHAR(255),
    downloadReplaceMask NVARCHAR(MAX),
    audioBitrate INT,
    videoBitrate INT,
    width INT,
    height INT,
    settings NVARCHAR(1024),
    icc_profile NVARCHAR(512),
    no_security_folder nvarchar(max),
    pre_generate_folders nvarchar(max)
);

-- Create temp table for keeping track of the migrated formats.
CREATE TABLE #migratedFormats(
    mediaFormatId INT,
    formatId INT,
    extension NVARCHAR(8),
    details NVARCHAR(MAX)
);

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Thumbnail';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = 'e579a06d-ea32-451f-a3d3-b937224c2ffa');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[0]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'webp', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Large Thumbnail';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = '7fb6d99b-9d25-4fb3-831f-b6c51ac08782');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[0]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'webp', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'PDF';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = 'ad44feb1-7038-42a3-a56a-453c76eec8c0');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[5,8,9,14,100,101,102,103,105,106,107,108,111,112]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'pdf', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Video Preview';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = '8bbd835f-80de-460e-bd68-23ef8cc545b4');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[1]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'mp4', @details);
END

SELECT @formatId=Id, @details=Details FROM [dbo].[Formats] WHERE [Name] = 'Audio Preview';
IF @formatId IS NOT NULL
BEGIN
    SET @mediaFormatId = (SELECT imf.media_formatid
                          FROM item_media_format imf
                          JOIN item i on imf.itemid = i.itemid
                          WHERE i.ItemGuid = '75a39459-ba5f-46aa-897b-3cb915a91c70');

    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    UPDATE [dbo].[Formats]
    SET ImmediatelyGeneratedFor='[2]'
    WHERE Id=@formatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, 'mp3', @details);
END


-- Try migrating each media format that isn't already migrated.
INSERT INTO #mediaFormatsToProcess
SELECT mf.media_formatid, mf.media_format_typeid, mfl.medianame, mf.download_replace_mask,
       mf.audiobitrate, mf.videobitrate, mf.width, mf.height, mf.settings, mf.icc_profile,

       coalesce((select json_arrayagg(t.LayoutfolderId)
                 from (select distinct LPD.LayoutfolderId
                       from dz_profileformat pf
                                join dz_profile p on pf.dz_profileid = p.dz_profileid
                                join Layoutfolder_Profile_Destination LPD on p.dz_profileid = LPD.Dz_ProfileId
                                join digitranscode_destination maybe_storage_manager_destination
                                     on LPD.DestinationId =
                                        maybe_storage_manager_destination.digitranscode_destinationid
                                left join digitranscode_destination maybe_specific_destination
                                          on maybe_specific_destination.StorageManagerId =
                                             maybe_storage_manager_destination.digitranscode_destinationid
                       where mf.media_formatid = pf.media_formatid
                         and (maybe_storage_manager_destination.LaxSecurity = 1 or
                              maybe_specific_destination.LaxSecurity = 1)) as t), '[]') as no_security_folder,

       coalesce(
               (select json_arrayagg(t.LayoutfolderId)
                from (select distinct LPD.LayoutfolderId
                      from dz_profileformat pf
                               join dz_profile p on pf.dz_profileid = p.dz_profileid
                               join Layoutfolder_Profile_Destination LPD on p.dz_profileid = LPD.Dz_ProfileId
                      where mf.media_formatid = pf.media_formatid) as t)
           , '[]') as pre_generate_folders

FROM [dbo].[media_format] mf
JOIN [dbo].[media_format_language] mfl ON mf.media_formatid=mfl.media_formatid
WHERE mf.mapped_to_format_id IS NULL AND mfl.languageid=3;

WHILE(EXISTS(SELECT NULL FROM #mediaFormatsToProcess))
BEGIN
    SELECT TOP 1
           @mediaFormatId=mediaFormatId,
           @mediaFormatTypeId=mediaFormatTypeId,
           @name=name,
           @downloadReplaceMask=downloadReplaceMask,
           @audioBitrate=audioBitrate,
           @videoBitrate=videoBitrate,
           @width=width,
           @height=height,
           @settings=settings,
           @iccProfile=icc_profile,
           @pre_generate_folders=pre_generate_folders,
           @no_security_folder=no_security_folder
    FROM #mediaFormatsToProcess;
    DELETE FROM #mediaFormatsToProcess WHERE mediaFormatId=@mediaFormatId;

    IF EXISTS(SELECT NULL FROM [dbo].[Formats] WHERE [Name]=@name)
    BEGIN
        print 'Can not migrate the media format ' + CONVERT(NVARCHAR(10), @mediaFormatId) + ' since a format with the name "' + @name + '" already exists';
    CONTINUE;
    END

    -- Get the extension of the media format.
    SELECT TOP 1 @extension=LOWER(extension) FROM [dbo].[media_format_type_extension] WHERE media_format_typeid=@mediaFormatTypeId;

    IF @extension IN ('jpg', 'jpeg', 'png', 'webp', 'avif', 'tif', 'tiff') AND (@settings IS NULL OR @settings='')
    BEGIN
        print 'No ImageMagick command is available for the image media format ' + CONVERT(NVARCHAR(10), @mediaFormatId) + '. ' +
              'Can only migrate image media formats with ImageMagick commands.';
        CONTINUE;
    END

    -- Escape backslashes and double-quotes to ensure that the corresponding string is a valid JSON string.
    SET @settings = REPLACE(@settings, '\', '\\');
    SET @settings = REPLACE(@settings, '"', '\u0022');
    
    -- Enum values correspond with 'Libs/LegacyService.Shared/Enums/Images/CMYKAllowedColorSpace.cs'
    SET @colorSpaceEnum = '0'; -- Preserve
    IF CHARINDEX('%iccconversion%', @settings) > 0 AND @iccProfile IS NOT NULL
        BEGIN;
            IF @iccProfile = 'AdobeRGB1998.icc' SET @colorSpaceEnum = '1';
            ELSE IF @iccProfile = 'sRGB.icc' SET @colorSpaceEnum = '2';
            ELSE IF @iccProfile = 'Generic_CMYK.icc' SET @colorSpaceEnum = '3';
        END;

    -- Get the new format details.
    IF @extension='jpg' OR @extension='jpeg'
    BEGIN
        SET @extension='jpeg';
        SET @details = '{"type":"JpegImageFormat",' +
                        '"BackgroundColor":"transparent",' +
                        '"ColorSpace":' + @colorSpaceEnum + ',' +
                        '"Quality":0,' +
                        '"TargetMaxSize":null,' +
                        '"Interlace":true,' +
                        '"CropWidth":0,' +
                        '"CropHeight":0,' +
                        '"CropPosition":4,' +
                        '"Clip":false,' +
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' +
                        '"AutoOrient":true,' +
                        '"RemoveFileMetadata":false,' +
                        '"WatermarkAssetId":0,' +
                        '"WatermarkAssetExtension":"",' +
                        '"WatermarkPosition":4,' +
                        '"WatermarkCoveragePercentage":0,' +
                        '"WatermarkOffsetX":0,' +
                        '"WatermarkOffsetY":0,' +
                        '"WatermarkOpacityPercentage":0,' +
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' +
                        '"Width":0,' +
                        '"ResizeMode":2,' +
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='png'
    BEGIN
        SET @details = '{"type":"PngImageFormat",' +
                        '"ColorSpace":' + @colorSpaceEnum + ',' +
                        '"CompressionLevel":7,' +
                        '"Interlace":true,' +
                        '"BackgroundColor":"transparent",' +
                        '"CropWidth":0,' +
                        '"CropHeight":0,' +
                        '"CropPosition":4,' +
                        '"Clip":false,' +
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' +
                        '"AutoOrient":true,' +
                        '"RemoveFileMetadata":false,' +
                        '"WatermarkAssetId":0,' +
                        '"WatermarkAssetExtension":"",' +
                        '"WatermarkPosition":4,' +
                        '"WatermarkCoveragePercentage":0,' +
                        '"WatermarkOffsetX":0,' +
                        '"WatermarkOffsetY":0,' +
                        '"WatermarkOpacityPercentage":0,' +
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' +
                        '"Width":0,' +
                        '"ResizeMode":2,' +
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='webp'
    BEGIN
        SET @details = '{"type":"WebPImageFormat",' +
                        '"ColorSpace":' + @colorSpaceEnum + ',' +
                        '"Quality":0,' +
                        '"BackgroundColor":"transparent",' +
                        '"CropWidth":0,' +
                        '"CropHeight":0,' +
                        '"CropPosition":4,' +
                        '"Clip":false,' +
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' +
                        '"AutoOrient":true,' +
                        '"RemoveFileMetadata":false,' +
                        '"WatermarkAssetId":0,' +
                        '"WatermarkAssetExtension":"",' +
                        '"WatermarkPosition":4,' +
                        '"WatermarkCoveragePercentage":0,' +
                        '"WatermarkOffsetX":0,' +
                        '"WatermarkOffsetY":0,' +
                        '"WatermarkOpacityPercentage":0,' +
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' +
                        '"Width":0,' +
                        '"ResizeMode":2,' +
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='avif'
    BEGIN
        SET @details = '{"type":"AvifImageFormat",' +
                        '"ColorSpace":' + @colorSpaceEnum + ',' +
                        '"Quality":0,' +
                        '"BackgroundColor":"transparent",' +
                        '"CropWidth":0,' +
                        '"CropHeight":0,' +
                        '"CropPosition":4,' +
                        '"Clip":false,' +
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' +
                        '"AutoOrient":true,' +
                        '"RemoveFileMetadata":false,' +
                        '"WatermarkAssetId":0,' +
                        '"WatermarkAssetExtension":"",' +
                        '"WatermarkPosition":4,' +
                        '"WatermarkCoveragePercentage":0,' +
                        '"WatermarkOffsetX":0,' +
                        '"WatermarkOffsetY":0,' +
                        '"WatermarkOpacityPercentage":0,' +
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' +
                        '"Width":0,' +
                        '"ResizeMode":2,' +
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='tif' OR @extension='tiff'
    BEGIN
        SET @extension='tiff';
        SET @details = '{"type":"TiffImageFormat",' +
                        '"ColorSpace":' + @colorSpaceEnum + ',' +
                        '"BackgroundColor":"transparent",' +
                        '"CropWidth":0,' +
                        '"CropHeight":0,' +
                        '"CropPosition":4,' +
                        '"Clip":false,' +
                        '"DotsPerInchX":72,' +
                        '"DotsPerInchY":72,' +
                        '"AutoOrient":true,' +
                        '"RemoveFileMetadata":false,' +
                        '"WatermarkAssetId":0,' +
                        '"WatermarkAssetExtension":"",' +
                        '"WatermarkPosition":4,' +
                        '"WatermarkCoveragePercentage":0,' +
                        '"WatermarkOffsetX":0,' +
                        '"WatermarkOffsetY":0,' +
                        '"WatermarkOpacityPercentage":0,' +
                        '"CustomConversionCommand":"' + @settings + '",' +
                        '"Height":0,' +
                        '"Width":0,' +
                        '"ResizeMode":2,' +
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0}';
    END
    ELSE IF @extension='mp3'
    BEGIN
        SET @compressionLevel = CASE
            WHEN @audioBitrate = 0 THEN 4
            WHEN @audioBitrate <= 128000 THEN 6
            WHEN @audioBitrate < 192000 THEN 4
            ELSE 2
        END;
        SET @details = '{"type":"Mp3AudioFormat",' +
                        '"CompressionLevel":' + CONVERT(NVARCHAR(10), @compressionLevel);

        if @audioBitrate<>0
            begin
                        set @details = @details + ',"Bitrate":' + CONVERT(NVARCHAR(10), @audioBitrate)
            end

            set @details = @details + '}';
    END
    ELSE IF @extension='avi'
    BEGIN
        SET @details = '{"type":"AviVideoFormat",' +
                        '"BackgroundColor":"#00000000",' +
                        '"CompressionLevel":23,';

        IF @videoBitrate<>0
        begin
            set @details = @details +
                        '"VideoBitrate":' + CONVERT(NVARCHAR(10), @videoBitrate) + ',';
        end;


        IF @audioBitrate<>0
        begin
            set @details = @details +
                        '"AudioBitrate":' + CONVERT(NVARCHAR(10), @audioBitrate) + ',';
        end;

        set @details = @details +
                        '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                        '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                        '"ResizeMode":0,' + -- fixed size
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0' +
                        '}';
    END
    ELSE IF @extension='mov'
    BEGIN
        SET @details = '{"type":"MovVideoFormat",' +
                        '"BackgroundColor":"#00000000",' +
                        '"CompressionLevel":23,';

        IF @videoBitrate<>0
        begin
            set @details = @details +
                        '"VideoBitrate":' + CONVERT(NVARCHAR(10), @videoBitrate) + ',';
        end;


        IF @audioBitrate<>0
        begin
            set @details = @details +
                        '"AudioBitrate":' + CONVERT(NVARCHAR(10), @audioBitrate) + ',';
        end;

        set @details = @details +
                        '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                        '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                        '"ResizeMode":0,' + -- fixed size
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0' +
                        '}';
    END
    ELSE IF @extension='mp4'
    BEGIN
        SET @details = '{"type":"Mp4VideoFormat",' +
                        '"BackgroundColor":"#00000000",' +
                        '"CompressionLevel":23,';

        IF @videoBitrate<>0
        begin
            set @details = @details +
                        '"VideoBitrate":' + CONVERT(NVARCHAR(10), @videoBitrate) + ',';
        end;


        IF @audioBitrate<>0
        begin
            set @details = @details +
                        '"AudioBitrate":' + CONVERT(NVARCHAR(10), @audioBitrate) + ',';
        end;

        set @details = @details +
                        '"Height":' + CONVERT(NVARCHAR(10), @height) + ',' +
                        '"Width":' + CONVERT(NVARCHAR(10), @width) + ',' +
                        '"ResizeMode":0,' + -- fixed size
                        '"BackgroundWidth":0,' +
                        '"BackgroundHeight":0' +
                        '}';

    END
    ELSE IF @extension='pdf'
        SET @details = '{"type":"PdfFormat"}'
    ELSE
    BEGIN
        print 'The extension "' + @extension + '" is not supported in the new transcode system. ' +
              'Can not migrate the media format ' + CONVERT(NVARCHAR(10), @mediaFormatId) + '.';
        CONTINUE;
    END

    -- Find asset types to generate renditions of the format for immediately.
    SET @immediatelyGeneratedFor = COALESCE(
        '[' + (SELECT STRING_AGG(assetType, ',') FROM digizuite_assettype_configs_upload_quality WHERE FormatId = @mediaFormatId) + ']',
        '[]'
    );

    -- Make the download replace mask prettier.
    -- This is technically not needed but helps to avoid confusion.
    SET @downloadReplaceMask = (SELECT REPLACE(@downloadReplaceMask, '[%MediaFormatId%]', '[%FormatId%]'));
    SET @downloadReplaceMask = (SELECT REPLACE(@downloadReplaceMask, '[%MediaFormatName%]', '[%FormatName%]'));

    set @assetFilter_AssetType = coalesce((select json_arrayagg(t.assetType)
                                           from (select pat.assettypeid as assetType
                                                 from dz_profileformat pf
                                                          join dz_profile p on pf.dz_profileid = p.dz_profileid
                                                          join dz_profile_assettype pat on p.dz_profileid = pat.dz_profileid
                                                 where pf.media_formatid = @mediaFormatId
                                                 union
                                                 select assetType as assetType
                                                 from digizuite_assettype_configs_upload_quality
                                                 where FormatId = @mediaFormatId) as t)
        , '[]');

    set @assetFilter_ChannelFolder = @pre_generate_folders;

    -- In case a format is setup to be generated immediately, always consider it available
    if exists(select * from digizuite_assettype_configs_upload_quality where FormatId = @mediaFormatId)
        begin
            set @assetFilter_ChannelFolder = '[]'
        end

    set @assetFilter = '{"AssetTypes":' + @assetFilter_AssetType + ',"ChannelFolderIds":' + @assetFilter_ChannelFolder + '}';

    -- Create new format.
    INSERT INTO [dbo].[Formats]([Name],[Description],[Category],[ImmediatelyGeneratedFor],[DownloadReplaceMask],[Details],[CreatedAt],[LastModified],[PreGenerateForChannelFolderIds],[NoSecurityWhenInChannelFolderIds],[AssetFilter])
    VALUES (@name, '', 0, @immediatelyGeneratedFor, NULLIF(@downloadReplaceMask, ''), @details, GETDATE(), GETDATE(), @pre_generate_folders, @no_security_folder, @assetFilter);

    SELECT @formatId=Id FROM [dbo].[Formats] WHERE [Name]=@name;

    -- Map the old format to the new format.
    UPDATE [dbo].[media_format]
    SET mapped_to_format_id=@formatId
    WHERE media_formatid=@mediaFormatId;

    INSERT INTO #migratedFormats(mediaFormatId, formatId, extension, details)
    VALUES (@mediaFormatId, @formatId, @extension, @details);
END
DROP TABLE #mediaFormatsToProcess;

-- Create an index to make the next query operation faster.
CREATE NONCLUSTERED INDEX [asset_filetable_Media_formatid_index] ON [dbo].[asset_filetable]
(
	[Media_formatid] ASC,
	[Processing] ASC
)
INCLUDE([assetid],[hashsha1],[destinationid],[Size],[fileName]);


-- Create rendition entries for the migrated formats to avoid re-transcoding.
WHILE EXISTS(SELECT NULL FROM #migratedFormats)
BEGIN
    SELECT TOP 1 @mediaFormatId=mediaFormatId, @formatId=formatId, @extension=extension, @details=details FROM #migratedFormats;
    DELETE FROM #migratedFormats WHERE mediaFormatId=@mediaFormatId AND formatId=@formatId;

    INSERT INTO [dbo].[Renditions]([FormatId],[AssetId],[FilePath],[FileSize],[Fingerprint],[State],[IgnoreSecurity],[ErrorMessage],[LastModified])
    SELECT @formatId,
           af.assetid,
           'assets/' + MIN(af.fileName),
           MAX(af.Size),
           COALESCE(UPPER(a.hashsha1), '') + '-' + @extension + '-' + @details,
           2,
           0, -- rely on the migration of profiles to IgnoreSecurity instead of hard-coding it on the rendition.
           NULL,
           GETDATE()
    FROM [dbo].[asset_filetable] af
        JOIN [dbo].[asset] a on af.assetid = a.assetid
    WHERE af.Media_formatid = @mediaFormatId
		AND af.Processing = 0
		AND NOT EXISTS(SELECT NULL FROM [dbo].[Renditions] r WHERE r.FormatId = @formatId AND r.AssetId = af.assetid)
    GROUP BY af.assetid, af.Media_formatid, a.hashsha1

    -- Migrate existing member group download qualities.
	INSERT INTO [dbo].[LoginService_GroupDownloadQualities]([MemberGroupId], [FormatId])
	SELECT q1.MemberGroupId, CONVERT(NVARCHAR(10), @formatId)
	FROM [dbo].[LoginService_GroupDownloadQualities] q1
	WHERE q1.FormatId=CONVERT(NVARCHAR(10), @mediaFormatId) AND
		  NOT EXISTS(SELECT NULL FROM [dbo].[LoginService_GroupDownloadQualities] q2
					 WHERE q1.MemberGroupId = q2.MemberGroupId AND q2.FormatId = CONVERT(NVARCHAR(10), @formatId));

	DELETE FROM [dbo].[LoginService_GroupDownloadQualities] WHERE FormatId = CONVERT(NVARCHAR(10), @mediaFormatId);
END
DROP TABLE #migratedFormats;


-- Prepare special-case migration of source copy media formats.
declare @source_copy_media_format_ids table (media_format_id int primary key);
insert into @source_copy_media_format_ids (media_format_id)
SELECT distinct target_media_formatid
FROM dbo.media_transcode
WHERE source_media_formatid IS NULL
  AND progid = 'DigiJobs.JobFileCopy';

-- Map the source copy media formats to the SourceFormat with the id -1.
UPDATE [dbo].[media_format]
SET mapped_to_format_id=-1
WHERE media_formatid IN (SELECT media_format_id FROM @source_copy_media_format_ids);

update Formats
set NoSecurityWhenInChannelFolderIds = coalesce((select json_arrayagg(t.LayoutfolderId)
                                                 from (select distinct LPD.LayoutfolderId
                                                       from dz_profileformat pf
                                                                join dz_profile p on pf.dz_profileid = p.dz_profileid
                                                                join Layoutfolder_Profile_Destination LPD
                                                                     on p.dz_profileid = LPD.Dz_ProfileId
                                                                join digitranscode_destination maybe_storage_manager_destination
                                                                     on LPD.DestinationId =
                                                                        maybe_storage_manager_destination.digitranscode_destinationid
                                                                left join digitranscode_destination maybe_specific_destination
                                                                          on maybe_specific_destination.StorageManagerId =
                                                                             maybe_storage_manager_destination.digitranscode_destinationid
                                                       where pf.media_formatid in
                                                             (SELECT media_format_id FROM @source_copy_media_format_ids)
                                                         and (maybe_storage_manager_destination.LaxSecurity = 1 or
                                                              maybe_specific_destination.LaxSecurity = 1)) as t), '[]'),
    PreGenerateForChannelFolderIds   = coalesce(
            (select json_arrayagg(t.LayoutfolderId)
             from (select distinct LPD.LayoutfolderId
                   from dz_profileformat pf
                            join dz_profile p on pf.dz_profileid = p.dz_profileid
                            join Layoutfolder_Profile_Destination LPD on p.dz_profileid = LPD.Dz_ProfileId
                   where pf.media_formatid in (SELECT media_format_id FROM @source_copy_media_format_ids)) as t)
        , '[]')
where Id = -1


drop index [asset_filetable_Media_formatid_index] ON [dbo].[asset_filetable];

SET NOCOUNT OFF;

-- Migration was successful, commit the changes.
COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    -- Migration was unsuccessful, rollback the changes.
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @msg NVARCHAR(MAX), @sev INT, @stt INT;
    SET @msg = N'ERROR: Number: ' + CAST(ERROR_NUMBER() as nvarchar(max)) + N', Message: ' + ERROR_MESSAGE();
    SET @sev = ERROR_SEVERITY();
    SET @stt = ERROR_STATE();
    RaisError(@msg, @sev, @stt);
END CATCH
