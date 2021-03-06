USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[nv17]    Script Date: 26.05.2022 13:40:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--select * from maxmast.imsu where imsu_item='00114957'
--select * from maxmast.mford
--exec [dbo].[fnv00_nv15] 'W_09_04337','10','ЛОГ1','СВОБМ','ПОДР','ХРАН','Т-7-1','00234','00002','00002','00114957',1,'test','test'
--exec [dbo].[fnv00_nv15] 'W_09_04337','10','ПОДР','ХРАН','ЛОГ1','СВОБМ','00234','Т-7-1','00002','00003','00114957',1,'test','test'

ALTER  procedure [dbo].[nv17] 
	@orderno char(20)
	, @fromstore char(5)
	, @fromacct char(5)
	, @tostore char(5)
	, @toacct char(5)
	, @frombin char(15)
	, @tobin char(15)
	, @sernofrom char(15)
	, @sernoto char(15)
	, @item char(22)
	, @itemqty float
	, @lui char(50)
	, @remarks char(45)
	, @showanswer int = 0
	, @serial char(100)
	, @act varchar( 50 ) = ''
	, @reason varchar( 30 ) = ''
	, @nvtrn_id int = -1 output
	, @tara varchar(100) = ''
	, @cell varchar(100) = ''
as
begin

	declare @row int = -1
	declare @column int = -1

	select @row = cpl.row_position 
		, @column = cpl.column_position
	from container_pin_list cpl
	where serial_number = @tara
		and cell_name = @cell

	set @row = isnull(@row , -1)
	set @column = isnull(@column , -1)
	set @tara = isnull(@tara, '')

	declare @pin_id int = 
		isnull(
			(
				select cpl.id 
				from container_pin_list cpl 
				where serial_number = @tara
					and cell_name = @cell
			)
		, -1)

	declare @cost float ,@imast_id int, @decimals int
	select @imast_id=imast_id,@decimals=imast_decimals 
	from maxmast.imast where imast_item=@item

	set @cost=(select imsu_price from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom)

	if ( select mford_completed from maxmast . mford where mford_orderno = @orderno ) = 'Y'
	begin
	
		select 
			'L`ordine ' + rtrim( @orderno ) + ' è chiuso!!!' as [error]
			,'L`ordine '+rtrim(@orderno)+' è chiuso!!!' as [answer]
		return 3
	end

	if not exists	( 
						select 
							nvbin_bin 
						from 
							maxmast . nvbin 
						where 
							nvbin_bin = @tobin
					)
	begin
	
		select 
			'Il luogo di stoccaggio [' + rtrim( @tobin ) + '] non è descritto' as [error]
			, 'Il luogo di stoccaggio [' + rtrim( @tobin ) + '] non è descritto' as [answer]
		return 3
		
	end

	if ( @sernofrom = '' )
	begin
	
		select 
			'Errore nell`articolo [' + @item + '] E’ obbligatorio inserire il numero di serie!' as [error]
			, 'Errore nell`articolo [' + @item + '] E’ obbligatorio inserire il numero di serie!' as [answer]
		return 3

	end

	if (	( select imast_tracecode from maxmast.imast where imast_item = @item ) = 'S' ) 
		and ( select count( * ) from maxmast.imsul 
		join maxmast.imsu on imsu_id=imsul_imsu_id
		join maxmast.imast on imast_id=imsu_item_id
		where (imast_item=@item) and (imsu_serno=@sernofrom) and imsul_balance > 0 ) > 0 and @itemqty > 0
	begin
	
		select 
			'Errore nell`articolo [' + @item + ']. L’articolo con questo numero  [' + @sernofrom + '] è già a magazzino.' as [error]
			, 'Errore nell`articolo [' + @item + ']. L’articolo con questo numero [' + @sernofrom + '] è già a magazzino.' as [answer]
		return 3
		
	end

	if ( ( ( select imast_tracecode from maxmast . imast where imast_item = @item ) = 'S' ) and ( abs ( @itemqty ) <> 1 ) ) 
	begin
		
		select 
			'Errore nell`articolo [' + @item + '] L`articolo è rintracciato per la matricola. E` inserita la grande quantità.' as [error]
			, 'Errore nell`articolo [' + @item + '] L`articolo è rintracciato per la matricola. E` inserita la grande quantità.' as [answer]
		return 3
		
	end

--Бреславец 21.10.16
--Разкоментил проверку по служебке от Таи, с заказа нельзя принять больше чем требуемое кол-во - уже принятое
	if /*isnull((select mford_dueqty-mford_qtyrcvd from maxmast.mford where mford_orderno=@orderno),0)*/
	isnull((select mford_monord from maxmast.mford where mford_orderno=@orderno),0)
	<@itemqty
	begin
	select 'Errore nell`articolo ['+@item+'] La quantità inserita eccede l`arrivo in attesa per l`ordine' as [error]
	,'Errore nell`articolo ['+@item+'] La quantità inserita eccede l`arrivo in attesa per l`ordine' as [answer]
	return 3
	end

	if @itemqty = 0 
	begin
	
		select 
			'Inserisci il valore diverso da zero per il trasferimento' as [error]
			, 'Inserisci il valore diverso da zero per il trasferimento' as [answer]
		return
	
	end
--Для склада ПРОИЗ не нужно прописывать связить изделия и склада
--Брак со заказа на работу приходит в ПРОИЗ БРАК(Раньше было в ДСЕ БРАК)
	if(@tostore<>'INPRO')
	begin
		if ( select count(*) from maxmast.imsto where ( imsto_item = @item ) and ( imsto_store = @tostore ) ) <> 1
		begin
		
			select 
				'Manca la riga nella tabella articolo-magazzino per l`articolo [' + @item + '] ' as [error]
				,'Manca la riga nella tabella articolo-magazzino per l`articolo [' + @item + '] ' as [answer]
			return 3
	
		end
	end	
--Добавил Бреславец 23.01.17
--Не понимаю почему этого небыло сразу и без данной проверки они приняли несколько изделий одновременно с разных заказов в одну партию	
	if exists (select * from maxmast.imsu
	join maxmast.imast on imast_id=imsu_item_id 
	where imast_item=@item and imsu_serno=@sernoto) and @itemqty > 0
	begin
		
		select 
			'Questa partita [' + @sernoto + '] è già accettata al magazzino' as [error]
			,'Questa partita [' + @sernoto + '] è già accettata al magazzino' as [answer]
		return 3
	
	end
--------------------------------------------------------------	

	set @itemqty=round(@itemqty,@decimals)

	SET XACT_ABORT ON

--DECLARE @sec int, @orderno char(10), @lineno int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float,@fromstore char(5),@fromacct char(5),@tostore char(5),@toacct char(5),@frombin char(15),@tobin char(15),@serno char(15),@item char(22),@itemqty float(8), @lui char(10), @curser char(15);
--DECLARE @sec int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float, @parent varchar(22);
--set @parent=(select mford_item from maxmast.mford where mford_orderno=@orderno)

/**************%%%%%%%%%%%%%%%%%%%%%Перемещение%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	declare @r int
	declare @nvtrn_id_nv00 int=0
	exec @r=[dbo].[nv00_all_complete] 
		@fromstore = @fromstore
		, @fromacct = @fromacct
		, @tostore = @tostore
		, @toacct = @toacct
		, @frombin = @frombin
		, @tobin = @tobin
		, @item = @item
		, @itemqty = @itemqty
		, @sernofrom = @sernofrom
		, @sernoto = @sernoto
		, @lui = @lui
		, @remarks = @remarks
		, @cost = @cost
		, @trantype = 'Or'
		, @type = 'Or'
		, @orderno = @orderno
		, @lineno = 0
		, @porderno = ''
		, @ordline = 0
		, @release = 0
		, @grn = ''
		, @act = @act
		, @reason = @reason
		, @NVTRNForwardID = @nvtrn_id_nv00 output
		, @SerialNum = @serial
		, @is_instr = 0
		, @expiredate = '19000101'--дата окончания срока годности из pu10
		, @from_pin_id = -1
		, @to_pin_id = @pin_id

	if @r<>0 begin return 3 end
	/**************%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	set @nvtrn_id=@nvtrn_id_nv00
	------------------------------------------MFORD-----------------------
	print('MFORD')
	update maxmast.mford set mford_qtyrcvd=mford_qtyrcvd+(case when @toacct='SCART' then 0 else @itemqty end)
	, mford_monord=(case when (mford_monord-@itemqty)<0 then 0 else (mford_monord-@itemqty) end)
	, mford_lud=convert(varchar(10), getdate(), 121), mford_lui=@lui where mford_orderno=@orderno

	declare @imastSerial int
	declare @imastId int
	select @imastId = imast_id
		, @imastSerial = imast_serial_type_id 
	from maxmast.imast with (nolock) where imast_item = @item

	if @imastSerial = 1
		begin
			exec dbo.nv46_serial_num_update
				@SerialNumber = @serial
				, @ImastId = @imastId
				, @NvtrnId = @nvtrn_id 
				, @ItemQty = @itemqty
				, @lui = @lui
		end


	if @showanswer=0 begin select ' ' as [error], 1 as answer end
	return 0 

end
/*bagdasar old version 2021-05-26
ALTER  procedure [dbo].[nv17] 
@orderno char(20)
,@fromstore char(5)
,@fromacct char(5)
,@tostore char(5)
,@toacct char(5)
,@frombin char(15)
,@tobin char(15)
,@sernofrom char(15)
,@sernoto char(15)
,@item char(22)
,@itemqty float
, @lui char(50)
, @remarks char(45)
, @showanswer int=0
, @serial char(100)
, @act varchar( 50 ) = ''
, @reason varchar( 30 ) = ''
, @nvtrn_id int = -1 output
as
begin

	declare @cost float ,@imast_id int, @decimals int
	select @imast_id=imast_id,@decimals=imast_decimals 
	from maxmast.imast where imast_item=@item

	set @cost=(select imsu_price from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom)

	if ( select mford_completed from maxmast . mford where mford_orderno = @orderno ) = 'Y'
	begin
	
		select 
			'L`ordine ' + rtrim( @orderno ) + ' è chiuso!!!' as [error]
			,'L`ordine '+rtrim(@orderno)+' è chiuso!!!' as [answer]
		return 3
	end

	if not exists	( 
						select 
							nvbin_bin 
						from 
							maxmast . nvbin 
						where 
							nvbin_bin = @tobin
					)
	begin
	
		select 
			'Il luogo di stoccaggio [' + rtrim( @tobin ) + '] non è descritto' as [error]
			, 'Il luogo di stoccaggio [' + rtrim( @tobin ) + '] non è descritto' as [answer]
		return 3
		
	end

	if ( @sernofrom = '' )
	begin
	
		select 
			'Errore nell`articolo [' + @item + '] E’ obbligatorio inserire il numero di serie!' as [error]
			, 'Errore nell`articolo [' + @item + '] E’ obbligatorio inserire il numero di serie!' as [answer]
		return 3

	end

	if (	( select imast_tracecode from maxmast.imast where imast_item = @item ) = 'S' ) 
		and ( select count( * ) from maxmast.imsul 
		join maxmast.imsu on imsu_id=imsul_imsu_id
		join maxmast.imast on imast_id=imsu_item_id
		where (imast_item=@item) and (imsu_serno=@sernofrom) and imsul_balance > 0 ) > 0 and @itemqty > 0
	begin
	
		select 
			'Errore nell`articolo [' + @item + ']. L’articolo con questo numero  [' + @sernofrom + '] è già a magazzino.' as [error]
			, 'Errore nell`articolo [' + @item + ']. L’articolo con questo numero [' + @sernofrom + '] è già a magazzino.' as [answer]
		return 3
		
	end

	if ( ( ( select imast_tracecode from maxmast . imast where imast_item = @item ) = 'S' ) and ( abs ( @itemqty ) <> 1 ) ) 
	begin
		
		select 
			'Errore nell`articolo [' + @item + '] L`articolo è rintracciato per la matricola. E` inserita la grande quantità.' as [error]
			, 'Errore nell`articolo [' + @item + '] L`articolo è rintracciato per la matricola. E` inserita la grande quantità.' as [answer]
		return 3
		
	end

--Бреславец 21.10.16
--Разкоментил проверку по служебке от Таи, с заказа нельзя принять больше чем требуемое кол-во - уже принятое
	if /*isnull((select mford_dueqty-mford_qtyrcvd from maxmast.mford where mford_orderno=@orderno),0)*/
	isnull((select mford_monord from maxmast.mford where mford_orderno=@orderno),0)
	<@itemqty
	begin
	select 'Errore nell`articolo ['+@item+'] La quantità inserita eccede l`arrivo in attesa per l`ordine' as [error]
	,'Errore nell`articolo ['+@item+'] La quantità inserita eccede l`arrivo in attesa per l`ordine' as [answer]
	return 3
	end

	if @itemqty = 0 
	begin
	
		select 
			'Inserisci il valore diverso da zero per il trasferimento' as [error]
			, 'Inserisci il valore diverso da zero per il trasferimento' as [answer]
		return
	
	end
--Для склада ПРОИЗ не нужно прописывать связить изделия и склада
--Брак со заказа на работу приходит в ПРОИЗ БРАК(Раньше было в ДСЕ БРАК)
	if(@tostore<>'INPRO')
	begin
		if ( select count(*) from maxmast.imsto where ( imsto_item = @item ) and ( imsto_store = @tostore ) ) <> 1
		begin
		
			select 
				'Manca la riga nella tabella articolo-magazzino per l`articolo [' + @item + '] ' as [error]
				,'Manca la riga nella tabella articolo-magazzino per l`articolo [' + @item + '] ' as [answer]
			return 3
	
		end
	end	
--Добавил Бреславец 23.01.17
--Не понимаю почему этого небыло сразу и без данной проверки они приняли несколько изделий одновременно с разных заказов в одну партию	
	if exists (select * from maxmast.imsu
	join maxmast.imast on imast_id=imsu_item_id 
	where imast_item=@item and imsu_serno=@sernoto) and @itemqty > 0
	begin
		
		select 
			'Questa partita [' + @sernoto + '] è già accettata al magazzino' as [error]
			,'Questa partita [' + @sernoto + '] è già accettata al magazzino' as [answer]
		return 3
	
	end
--------------------------------------------------------------	

	set @itemqty=round(@itemqty,@decimals)

	SET XACT_ABORT ON

--DECLARE @sec int, @orderno char(10), @lineno int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float,@fromstore char(5),@fromacct char(5),@tostore char(5),@toacct char(5),@frombin char(15),@tobin char(15),@serno char(15),@item char(22),@itemqty float(8), @lui char(10), @curser char(15);
--DECLARE @sec int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float, @parent varchar(22);
--set @parent=(select mford_item from maxmast.mford where mford_orderno=@orderno)

/**************%%%%%%%%%%%%%%%%%%%%%Перемещение%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	declare @r int
	declare @nvtrn_id_nv00 int=0
	exec @r=[dbo].[nv00_all_complete] @fromstore,@fromacct,@tostore,@toacct,@frombin,@tobin
	,@item,@itemqty,@sernofrom,@sernoto,@lui,@remarks,@cost,'Or','Or'
	,@orderno,0,'',0, 0,'', @act, @reason, @nvtrn_id_nv00 output, @serial
	if @r<>0 begin return 3 end
	/**************%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	set @nvtrn_id=@nvtrn_id_nv00
	------------------------------------------MFORD-----------------------
	print('MFORD')
	update maxmast.mford set mford_qtyrcvd=mford_qtyrcvd+(case when @toacct='SCART' then 0 else @itemqty end)
	, mford_monord=(case when (mford_monord-@itemqty)<0 then 0 else (mford_monord-@itemqty) end)
	, mford_lud=convert(varchar(10), getdate(), 121), mford_lui=@lui where mford_orderno=@orderno


	if @showanswer=0 begin select ' ' as [error], 1 as answer end
	return 0 

end
*/




















