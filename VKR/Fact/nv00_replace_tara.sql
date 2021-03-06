USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[nv00_replace_tara]    Script Date: 26.05.2022 13:36:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER proc [dbo].[nv00_replace_tara] 
	@login varchar(50) = 'bagdasar'
	, @tara varchar(100) = ''
as
begin
	declare @CONST_NVACC_ID_DISP int = 
		(select nvacc_id from maxmast.nvacc where nvacc_account = 'DISP')

	if not exists 
		(
			select * 
			from dbo.container_pin_list cpl
				inner join imsul_pack imp on imp.ip_pack = cpl.serial_number
					and imp.ip_row = cpl.row_position
					and imp.ip_column = cpl.column_position
					and imp.ip_nvacc_id = @CONST_NVACC_ID_DISP
					and imp.ip_balance > 0 
			where cpl.serial_number = @tara
		)
	begin
		--select 'В таре ничего не лежит в виде запаса "DISP"' as rtext
		select 'Il contenitore non contiene niente sotto forma di scorta "DISP"' as rtext
		return
	end

	declare @tara_guid varchar(50) = 
		isnull(
		(
			select top 1 
				nvbin_GUID
				--, nvbin_bin
			from imsu_serial_nums
				inner join maxmast.imsu on imsu_isn_id = isn_id
				inner join maxmast.imsul on imsul_imsu_id = imsu_id
				inner join maxmast.imast on imast_id = imsu_item_id
				inner join maxmast.nvbin on nvbin_id = imsul_nvbin_id
			where isn_serial = @tara 
				and imsul_balance > 0
		)
		, '')

						--select * from maxmast.nvbin where nvbin_bin = 'M127-B002 '
						--select newid()     

	if (isnull(@tara_guid, '') = '')
	begin
		select 'Il luogo di stoccaggio del contenitore non è stato trovato' as rtext
		--'Место хранения тары не найдено' 
		return
	end

	--declare @tobin_GUID_const_2 varchar(50) = '1AC29944-0F9D-4E94-BCB3-7B3F6CAC9F25'
	 
/*	exec [dbo].[create_iems_process_PMV03_01_04_B] 
		NULL
		, @tara
		, @tara_guid
		, ''--@tobin_GUID_const_2
*/
	declare @CONST_DESTINATION_MAIN_WAREHOUSE varchar(50) = 'M131-WH01'
	declare @CONST_DEPARTURE_PICKING_POSITION_BIN_NAME varchar(50) = 'M120-MI01'

	set @tara = @tara + ';'

	exec [dbo].[create_iems_process_PMV02] 
	@parent_id = null
	, @taras = @tara
	, @destination = @CONST_DESTINATION_MAIN_WAREHOUSE
	, @status = 1
	, @description = ''
	, @departure = @CONST_DEPARTURE_PICKING_POSITION_BIN_NAME
	, @refreshContents ='Yes'


	select 'Il processo di spostamento del contenitore PMV03_01_04_B è stato creato' as rtext
	--'Процесс перемещения тары PMV03_01_04_B создан'

	/*end
	else
	begin
		select 'Тара не нуждается в перемещении' as rtext
	end*/
end