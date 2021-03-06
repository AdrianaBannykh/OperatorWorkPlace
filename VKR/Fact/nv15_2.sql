USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[nv15_2]    Script Date: 26.05.2022 13:39:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--select * from maxmast.imsu where imsu_item='00114957'


--select * from maxmast.mford
--exec [dbo].[fnv00_nv15] 'W_09_04337','10','ЛОГ1','СВОБМ','ПОДР','ХРАН','Т-7-1','00234','00002','00002','00114957',1,'test','test'
--exec [dbo].[fnv00_nv15] 'W_09_04337','10','ПОДР','ХРАН','ЛОГ1','СВОБМ','00234','Т-7-1','00002','00003','00114957',1,'test','test'
--Процедура выдаем компонент под заказ на работу
ALTER procedure [dbo].[nv15_2]
(
		@orderno char(20)
	, @lineno int
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
	, @forwardid int = -1
	, @serial varchar(100)=''
	, @tara varchar(100) = ''
	, @cell varchar(100) = ''

)
AS
BEGIN

		declare @pin_id int = 
		isnull(
			(
				select cpl.id 
				from container_pin_list cpl 
				where serial_number = @tara
					and cell_name = @cell
			)
		, -1)

	declare @cost float, @decimals int ,@imast_id int,@imsu_id int,@orderno_id int,@sernofrom_id int,@sernoto_id int, @isn_id int
	select @decimals=imast_decimals,@imast_id=imast_id from maxmast.imast where imast_item=@item
	select @cost =imsu_price,@sernofrom_id= imsu_id from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom
	set @orderno_id=(select mford_id from maxmast.mford where mford_orderno=@orderno)
	select @sernoto_id= imsu_id , @isn_id = imsu_isn_id from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom

	set @itemqty = round(@itemqty, @decimals)

	if ( substring(@orderno,1,1) = 'D' )
		begin
			if exists
			(
				select *
				from maxmast.nvtrn as n1
					inner join maxmast.imast on imast_id=n1.nvtrn_item_id
					inner join maxmast.mford on mford_orderno=n1.nvtrn_origin and mford_item_id=n1.nvtrn_item_id
				where n1.nvtrn_origin = @orderno
					and n1.nvtrn_item_id = @imast_id
					and n1.nvtrn_trancode_id in (1)--'Wi'
					and substring(@orderno,1,1) = 'D'
					and imast_tracecode='B' 
					and
					(
						select sum(n2.nvtrn_qty)
						from maxmast.nvtrn n2
						where n2.nvtrn_origin=@orderno
							and n2.nvtrn_item_id=@imast_id
							and  n1.nvtrn_trancode_id in (1)--'Wi'
							and substring(@orderno,1,1)='D'
							and imast_tracecode='B' 
							and n2.nvtrn_serno_id<>@sernoto_id
					) > 0
			)
				begin --'Изделие '+@item+' уже было выдано под этот заказ'
					select 'L’articolo '+rtrim(@item)+' è stato già rilasciato per questo ordine' as [error]
						, 'L’articolo '+rtrim(@item)+' è stato già rilasciato per questo ordine' as answer
					return 3
				end
		end

	if ( @itemqty > 0 and substring(@orderno,1,1)='K' and exists (select * from [dbo].[imsul_otvhr] 
	where o_item_id=@imast_id and o_orderno_id=@orderno_id and o_serno_id<>@sernofrom_id) )
		begin --'Изделие уже выдавалось под заказ "' + rtrim(@orderno) + '" из другой партии.'
			select 'L’articolo è stato già rilasciato per l’ordine "' + rtrim(@orderno) + '" di un altro lotto.' as answer
			return 3
		end

	if not exists(select nvbin_bin from maxmast.nvbin where nvbin_bin=@frombin)
		begin
			select --'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не существует места хранения ['+@frombin+']'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Non esiste il luogo di deposito ['+rtrim(@frombin)+']' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Non esiste il luogo di deposito ['+rtrim(@frombin)+']' as [answer]
			return 3
		end

	if (@fromacct!='IMPER') and (@fromacct!='SFRID') and isnull((select round(imast_freestock,@decimals) from maxmast.imast where imast_item=@item),0)<@itemqty
	begin --'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не достаточно запаса для данной строки'
		select 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta per questa riga non è sufficiente' as [error]
			, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta per questa riga non è sufficiente' as [answer]
		return 3
	end

	if round(isnull((select imsul_balance - imsul_osallqty 
	from maxmast.imsul 
		join maxmast.imsu on imsu_id=imsul_imsu_id
		join maxmast.imast on imast_id=imsu_item_id
		left join maxmast.nvbin on nvbin_id=imsul_nvbin_id
		join maxmast.nvsto on nvsto_id=imsul_store_id
		join maxmast.nvacc on nvacc_id=imsul_nvacc_id
	where  (imast_item=@item)
		and (nvsto_store=@fromstore)
		and (nvacc_account=@fromacct)
		and (ISNULL(nvbin_bin,'')=@frombin)
		and (imsu_serno=@sernofrom)),0),@decimals)<@itemqty and @item<>'00144628'
		begin
			select --'?????? ?? ?????? ['+str(@lineno)+'] ??????? ['+@item+'] ?? ?????????? ?????? ? ??????'

			
								'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta nel lotto non è sufficiente' as [error]
							, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta nel lotto non è sufficiente '+cast( @itemqty as varchar(10)) 
				
				
							+ cast(round(isnull((select imsul_balance - imsul_osallqty 
				from maxmast.imsul 
					join maxmast.imsu on imsu_id=imsul_imsu_id
					join maxmast.imast on imast_id=imsu_item_id
					left join maxmast.nvbin on nvbin_id=imsul_nvbin_id
					join maxmast.nvsto on nvsto_id=imsul_store_id
					join maxmast.nvacc on nvacc_id=imsul_nvacc_id
				where  (imast_item=@item)
					and (nvsto_store=@fromstore)
					and (nvacc_account=@fromacct)
					and (ISNULL(nvbin_bin,'')=@frombin)
					and (imsu_serno=@sernofrom)),0),@decimals) as varchar(20))
				
							as [answer]
						return 3
		end

	if @itemqty>0 and round(isnull((select mrcpt_dueqty from maxmast.mrcpt 
	where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno),0),@decimals)<cast(@itemqty as decimal(18,10))
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Выдаваемое кол-во превосходит требуемое'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità rilasciata  supera quella richiesta' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità rilasciata  supera quella richiesta' as [answer]
			return 3
		end

	if ( @itemqty<0 and -@itemqty>round(isnull((select mrcpt_issqty from maxmast.mrcpt 
	where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno),-1),@decimals) )
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata' as [answer]
			return 3
		end

	if ( @itemqty<0 and -@itemqty>round(isnull((select sum(nvtrn_qty) from maxmast.nvtrn with (readuncommitted) 
	where nvtrn_origin=@orderno and nvtrn_item_id=@imast_id and nvtrn_serno_id=@sernoto_id),-1),@decimals) )
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное по данной партии'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata per questo lotto' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata per questo lotto' as [answer]
			return 3
		end

	if ( @itemqty=0 )
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Введено нулевое колличество'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Inserita quantità zero' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Inserita quantità zero' as [answer]
			return 3
		end

	SET XACT_ABORT ON
	begin tran tran1
	--DECLARE @sec int, @orderno char(10), @lineno int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float,@fromstore char(5),@fromacct char(5),@tostore char(5),@toacct char(5),@frombin char(15),@tobin char(15),@serno char(15),@item char(22),@itemqty float(8), @lui char(10), @curser char(15);
	--DECLARE @sec int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float, @parent varchar(22);
	--set @parent=(select mford_item from maxmast.mford where mford_orderno=@orderno)

	/**************%%%%%%%%%%%%%%%%%%%%%Перемещение%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	print('[nv00_all_complete]')
	declare @r int
	/*exec @r = [dbo].[nv00_all_complete]
								@fromstore,@fromacct,@tostore,@toacct,@frombin,@tobin
							, @item,@itemqty,@sernofrom,@sernoto,@lui,@remarks,@cost,'Wi','Wi'
							,@orderno,@lineno, '', 0, 0, '', '', '', @forwardid,@serial*/
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
		, @trantype = 'Wi'
		, @type = 'Wi'
		, @orderno = @orderno
		, @lineno = @lineno
		, @porderno = ''
		, @ordline = 0
		, @release = 0
		, @grn = ''
		, @act = ''
		, @reason = ''
		, @NVTRNForwardID = @forwardid output
		, @SerialNum = @serial
		, @is_instr = 0
		, @expiredate = '19000101'--дата окончания срока годности из pu10
		, @from_pin_id = @pin_id
		, @to_pin_id = -1 
			
	if ( @r <> 0 ) 
	begin 
		rollback tran tran1
		return 3 
	end
	/**************%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	print('[nv00_all_complete] end')
	-----------------------------------------MRCPT----------------------
	print('MRCPT')
	if not exists(select * from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
		begin 
			--RAISERROR ('Ошибка...............', 16 ,1)
			select -- 'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Отсутствует строка в таблице MRCPT'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] E’ assente una riga nella tabella MRCPT' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] E’ assente una riga nella tabella MRCPT' as [answer]
			rollback tran tran1
			return 3
		end
	
	update maxmast.mrcpt
		set mrcpt_issqty = round(mrcpt_issqty + @itemqty,@decimals)
			, mrcpt_lud = convert(varchar(10), getdate(), 121)
			, mrcpt_lui = @lui
		where mrcpt_orderno_id = @orderno_id and mrcpt_lineno=@lineno

	if abs((select round(mrcpt_issqty-mrcpt_dueqty,@decimals) 
	from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno))<'0.0000001'
		begin
			update
				maxmast.mrcpt
			set
				mrcpt_issqty = 
--Изменил Бреславец 02,04,18 т.к. мы перемещаем округленное в большую сторону				
				round(mrcpt_dueqty,@decimals)--mrcpt_dueqty
			where
				mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno
		end

	if (select round(mrcpt_dueqty-mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)<0
		begin
			--select
			--		'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT' as [error]
			--	, 'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT' as [answer]
			--rollback tran tran1
			declare @qty_over float=(select round(mrcpt_dueqty-mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			declare @qty_1 float=(select round(mrcpt_dueqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			declare @qty_2 float=(select round(mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			
			select -- '*Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT (остаток:'+ltrim(str(@qty_over))+')'
				'*Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Consumo eccessivo di componenti nella tabella MRCPT (resido:'+ltrim(str(@qty_over))+')' as [error]
				, '**Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Consumo eccessivo di componenti nella tabella MRCPT '
			+cast(cast(@qty_over as numeric(10,8)) as char(20)) +cast(@qty_1 as CHAR(20))+cast(@qty_2 as CHAR(20)) as [answer]
			rollback tran tran1
			return 3
		end
		
	-----------------------------------------MRCPT_ITEMS---------------
	declare @mrcpt_id int
	set @mrcpt_id = 
	(
		select top 1
			mrcpt_id
		from
			maxmast.mrcpt
		where
					mrcpt_orderno_id = @orderno_id
			and mrcpt_lineno = @lineno
	)

		exec [dbo].[nv15_set_mrcpt_items]
			@orderno = @orderno
		, @lineno = @lineno
		, @item = @item
		, @serno = @sernofrom
		, @itemqty = @itemqty

	-----------------------------------------MRCPT_COSTS----------------
/*	print('MRCPT_COSTS')
	exec [dbo].[caa_mrcpt_set_costs]
		@mrcpt_id = @mrcpt_id
	
	-----------------------------------------MFORD_COSTS---------------
	print('MFORD_COSTS')
	exec [dbo].[caa_mford_set_costs]
		@orderno = @orderno
	, @item = @item
	, @serno = @sernofrom
	, @itemqty = @itemqty
		
	-----------------------------------------MRQT----------------------
*/	print('MRQT')
	update
		maxmast.mrqt
	set
		mrqt_dueqty = round(mrqt_dueqty-@itemqty,@decimals)
	where
		mrqt_rqtserial = (select top 1 mrcpt_rqtserial from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)

	-----------------------------------------IMAST_COMMIT---------------------
	print('IMAST')
	update maxmast.imast set 
	imast_commit=round(isnull((select sum(mrqt_dueqty) from maxmast.mrqt where mrqt_ordserial in (0,-1) and mrqt_item_id=@imast_id),0),@decimals)
	where (imast_item=@item)

--Копирование заводского номера в заказ при выдаче компонента с типом Тара
	declare @serial_type_id int = ISNULL((select imast_serial_type_id from maxmast.imast where imast_id = @imast_id), 1)
	declare @isn_serial varchar(100) =(select RTRIM(isn_serial) from imsu_serial_nums where isn_id = @isn_id)

	if  @serial_type_id in ( 4, 5) and @isn_serial<>''
	begin
		
		if @itemqty > 0 
			begin
				insert into maxmast.nv46_order_serial_num (mford_id, serial_num, status_id, sn_imast_id, creating_date, lud, lui)
				values (@orderno_id, @isn_serial, 1, @imast_id, GETDATE(), GETDATE(), @lui)
			end
		else
			begin
				delete from maxmast.nv46_order_serial_num
				where mford_id = @orderno_id and serial_num = @isn_serial
			end
	end
--------------------------------------------------------------------------
		declare @imastSerial int
		declare @imastId int
		select @imastId = imast_id
			, @imastSerial = imast_serial_type_id 
		from maxmast.imast with (nolock) where imast_item = @item
		
		declare @SerialNum varchar(100) = isnull( 
		(
			select isn_serial
			from maxmast.imsu 
				
				inner join [dbo].[imsu_serial_nums]  on imsu_isn_id=isn_id
			where imsu_item_id = @imast_id
				and imsu_serno = @sernofrom
		), '')
			
		if @imastSerial = 1
		begin
			exec dbo.nv46_serial_num_update
				@SerialNumber = @SerialNum
				, @ImastId = @imastId
				, @NvtrnId = @forwardid 
				, @ItemQty = @itemqty
				, @lui = @lui
		end


	--select * from maxmast.nvall
	commit tran tran1
	if ( @showanswer = 0 )
		begin
			select ' ' as [error], 1 as answer
			return 0
		end
END
/*
--Breslavetc 23.04.2021 - Добавлено копирование заводского номера в заказ из компонента типа Тара
ALTER procedure [dbo].[nv15_2]
(
		@orderno char(20)
	, @lineno int
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
	, @forwardid int = -1
	, @serial varchar(100)=''

)
AS
BEGIN
	declare @cost float, @decimals int ,@imast_id int,@imsu_id int,@orderno_id int,@sernofrom_id int,@sernoto_id int
	select @decimals=imast_decimals,@imast_id=imast_id from maxmast.imast where imast_item=@item
	select @cost =imsu_price,@sernofrom_id= imsu_id from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom
	set @orderno_id=(select mford_id from maxmast.mford where mford_orderno=@orderno)
	select @sernoto_id= imsu_id from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom

	set @itemqty = round(@itemqty, @decimals)

	if ( substring(@orderno,1,1) = 'D' )
		begin
			if exists
			(
				select *
				from maxmast.nvtrn as n1
					inner join maxmast.imast on imast_id=n1.nvtrn_item_id
					inner join maxmast.mford on mford_orderno=n1.nvtrn_origin and mford_item_id=n1.nvtrn_item_id
				where n1.nvtrn_origin = @orderno
					and n1.nvtrn_item_id = @imast_id
					and n1.nvtrn_trancode_id in (1)--'Wi'
					and substring(@orderno,1,1) = 'D'
					and imast_tracecode='B' 
					and
					(
						select sum(n2.nvtrn_qty)
						from maxmast.nvtrn n2
						where n2.nvtrn_origin=@orderno
							and n2.nvtrn_item_id=@imast_id
							and  n1.nvtrn_trancode_id in (1)--'Wi'
							and substring(@orderno,1,1)='D'
							and imast_tracecode='B' 
							and n2.nvtrn_serno_id<>@sernoto_id
					) > 0
			)
				begin --'Изделие '+@item+' уже было выдано под этот заказ'
					select 'L’articolo '+rtrim(@item)+' è stato già rilasciato per questo ordine' as [error]
						, 'L’articolo '+rtrim(@item)+' è stato già rilasciato per questo ordine' as answer
					return 3
				end
		end

	if ( @itemqty > 0 and substring(@orderno,1,1)='K' and exists (select * from [dbo].[imsul_otvhr] 
	where o_item_id=@imast_id and o_orderno_id=@orderno_id and o_serno_id<>@sernofrom_id) )
		begin --'Изделие уже выдавалось под заказ "' + rtrim(@orderno) + '" из другой партии.'
			select 'L’articolo è stato già rilasciato per l’ordine "' + rtrim(@orderno) + '" di un altro lotto.' as answer
			return 3
		end

	if not exists(select nvbin_bin from maxmast.nvbin where nvbin_bin=@frombin)
		begin
			select --'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не существует места хранения ['+@frombin+']'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Non esiste il luogo di deposito ['+rtrim(@frombin)+']' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Non esiste il luogo di deposito ['+rtrim(@frombin)+']' as [answer]
			return 3
		end

	if (@fromacct!='IMPER') and isnull((select round(imast_freestock,@decimals) from maxmast.imast where imast_item=@item),0)<@itemqty
	begin --'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не достаточно запаса для данной строки'
		select 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta per questa riga non è sufficiente' as [error]
			, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta per questa riga non è sufficiente' as [answer]
		return 3
	end

	if round(isnull((select imsul_balance - imsul_osallqty 
	from maxmast.imsul 
		join maxmast.imsu on imsu_id=imsul_imsu_id
		join maxmast.imast on imast_id=imsu_item_id
		left join maxmast.nvbin on nvbin_id=imsul_nvbin_id
		join maxmast.nvsto on nvsto_id=imsul_store_id
		join maxmast.nvacc on nvacc_id=imsul_nvacc_id
	where  (imast_item=@item)
		and (nvsto_store=@fromstore)
		and (nvacc_account=@fromacct)
		and (ISNULL(nvbin_bin,'')=@frombin)
		and (imsu_serno=@sernofrom)),0),@decimals)<@itemqty
		begin
			select --'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не достаточно запаса в партии'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta nel lotto non è sufficiente' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La scorta nel lotto non è sufficiente ' as [answer]
			return 3
		end

	if @itemqty>0 and round(isnull((select mrcpt_dueqty from maxmast.mrcpt 
	where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno),0),@decimals)<cast(@itemqty as decimal(18,10))
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Выдаваемое кол-во превосходит требуемое'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità rilasciata  supera quella richiesta' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità rilasciata  supera quella richiesta' as [answer]
			return 3
		end

	if ( @itemqty<0 and -@itemqty>round(isnull((select mrcpt_issqty from maxmast.mrcpt 
	where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno),-1),@decimals) )
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata' as [answer]
			return 3
		end

	if ( @itemqty<0 and -@itemqty>round(isnull((select sum(nvtrn_qty) from maxmast.nvtrn with (readuncommitted) 
	where nvtrn_origin=@orderno and nvtrn_item_id=@imast_id and nvtrn_serno_id=@sernoto_id),-1),@decimals) )
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное по данной партии'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata per questo lotto' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] La quantità restituita supera quella rilasciata per questo lotto' as [answer]
			return 3
		end

	if ( @itemqty=0 )
		begin
			select -- 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Введено нулевое колличество'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Inserita quantità zero' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Inserita quantità zero' as [answer]
			return 3
		end

	--SET XACT_ABORT ON
	--begin tran tran1
	--DECLARE @sec int, @orderno char(10), @lineno int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float,@fromstore char(5),@fromacct char(5),@tostore char(5),@toacct char(5),@frombin char(15),@tobin char(15),@serno char(15),@item char(22),@itemqty float(8), @lui char(10), @curser char(15);
	--DECLARE @sec int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float, @parent varchar(22);
	--set @parent=(select mford_item from maxmast.mford where mford_orderno=@orderno)

	/**************%%%%%%%%%%%%%%%%%%%%%Перемещение%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	print('[nv00_all_complete]')
	declare @r int
	exec @r = [dbo].[nv00_all_complete]
								@fromstore,@fromacct,@tostore,@toacct,@frombin,@tobin
							, @item,@itemqty,@sernofrom,@sernoto,@lui,@remarks,@cost,'Wi','Wi'
							,@orderno,@lineno, '', 0, 0, '', '', '', @forwardid,@serial
			
	if ( @r <> 0 ) begin return 3 end
	/**************%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	print('[nv00_all_complete] end')
	-----------------------------------------MRCPT----------------------
	print('MRCPT')
	if not exists(select * from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
		begin 
			--RAISERROR ('Ошибка...............', 16 ,1)
			select -- 'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Отсутствует строка в таблице MRCPT'
					'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] E’ assente una riga nella tabella MRCPT' as [error]
				, 'Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] E’ assente una riga nella tabella MRCPT' as [answer]
			--rollback tran tran1
			return 3
		end
	
	update maxmast.mrcpt
		set mrcpt_issqty = round(mrcpt_issqty + @itemqty,@decimals)
			, mrcpt_lud = convert(varchar(10), getdate(), 121)
			, mrcpt_lui = @lui
		where mrcpt_orderno_id = @orderno_id and mrcpt_lineno=@lineno

	if abs((select round(mrcpt_issqty-mrcpt_dueqty,@decimals) 
	from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno))<'0.0000001'
		begin
			update
				maxmast.mrcpt
			set
				mrcpt_issqty = 
--Изменил Бреславец 02,04,18 т.к. мы перемещаем округленное в большую сторону				
				round(mrcpt_dueqty,@decimals)--mrcpt_dueqty
			where
				mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno
		end

	if (select round(mrcpt_dueqty-mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)<0
		begin
			--select
			--		'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT' as [error]
			--	, 'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT' as [answer]
			--rollback tran tran1
			declare @qty_over float=(select round(mrcpt_dueqty-mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			declare @qty_1 float=(select round(mrcpt_dueqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			declare @qty_2 float=(select round(mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			
			select -- '*Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT (остаток:'+ltrim(str(@qty_over))+')'
				'*Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Consumo eccessivo di componenti nella tabella MRCPT (resido:'+ltrim(str(@qty_over))+')' as [error]
				, '**Errore nella riga ['+cast(@lineno as varchar)+'] articolo ['+rtrim(@item)+'] Consumo eccessivo di componenti nella tabella MRCPT '
			+cast(cast(@qty_over as numeric(10,8)) as char(20)) +cast(@qty_1 as CHAR(20))+cast(@qty_2 as CHAR(20)) as [answer]
			return 3
		end
		
	-----------------------------------------MRCPT_ITEMS---------------
	declare @mrcpt_id int
	set @mrcpt_id = 
	(
		select
			mrcpt_id
		from
			maxmast.mrcpt
		where
					mrcpt_orderno_id = @orderno_id
			and mrcpt_lineno = @lineno
	)

		exec [dbo].[nv15_set_mrcpt_items]
			@orderno = @orderno
		, @lineno = @lineno
		, @item = @item
		, @serno = @sernofrom
		, @itemqty = @itemqty

	-----------------------------------------MRCPT_COSTS----------------
/*	print('MRCPT_COSTS')
	exec [dbo].[caa_mrcpt_set_costs]
		@mrcpt_id = @mrcpt_id
	
	-----------------------------------------MFORD_COSTS---------------
	print('MFORD_COSTS')
	exec [dbo].[caa_mford_set_costs]
		@orderno = @orderno
	, @item = @item
	, @serno = @sernofrom
	, @itemqty = @itemqty
		
	-----------------------------------------MRQT----------------------
*/	print('MRQT')
	update
		maxmast.mrqt
	set
		mrqt_dueqty = round(mrqt_dueqty-@itemqty,@decimals)
	where
		mrqt_rqtserial = (select mrcpt_rqtserial from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)

	-----------------------------------------IMAST_COMMIT---------------------
	print('IMAST')
	update maxmast.imast set 
	imast_commit=round(isnull((select sum(mrqt_dueqty) from maxmast.mrqt where mrqt_ordserial in (0,-1) and mrqt_item_id=@imast_id),0),@decimals)
	where (imast_item=@item)

	--select * from maxmast.nvall
	--commit tran tran1
	if ( @showanswer = 0 )
		begin
			select ' ' as [error], 1 as answer
			return 0
		end
END

*/
--podzolov old version 2019/05/28 Удалена проверка распределения изделия (таблица nvall)
/*
ALTER procedure [dbo].[nv15_2]
(
		@orderno char(20)
	, @lineno int
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
	, @forwardid int = -1
	, @serial varchar(100)=''

)
AS
BEGIN
	declare @cost float, @decimals int ,@imast_id int,@imsu_id int,@orderno_id int,@sernofrom_id int,@sernoto_id int
	select @decimals=imast_decimals,@imast_id=imast_id from maxmast.imast where imast_item=@item
	select @cost =imsu_price,@sernofrom_id= imsu_id from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom
	set @orderno_id=(select mford_id from maxmast.mford where mford_orderno=@orderno)
	select @sernoto_id= imsu_id from maxmast.imsu where imsu_item_id=@imast_id and imsu_serno=@sernofrom

	set @itemqty = round(@itemqty, @decimals)

	if ( substring(@orderno,1,1) = 'D' )
		begin
			if exists
			(
				select *
				from maxmast.nvtrn as n1
					inner join maxmast.imast on imast_id=n1.nvtrn_item_id
					inner join maxmast.mford on mford_orderno=n1.nvtrn_origin and mford_item_id=n1.nvtrn_item_id
				where n1.nvtrn_origin = @orderno
					and n1.nvtrn_item_id = @imast_id
					and n1.nvtrn_trancode_id in (1)--'Wi'
					and substring(@orderno,1,1) = 'D'
					and imast_tracecode='B' 
					and
					(
						select sum(n2.nvtrn_qty)
						from maxmast.nvtrn n2
						where n2.nvtrn_origin=@orderno
							and n2.nvtrn_item_id=@imast_id
							and  n1.nvtrn_trancode_id in (1)--'Wi'
							and substring(@orderno,1,1)='D'
							and imast_tracecode='B' 
							and n2.nvtrn_serno_id<>@sernoto_id
					) > 0
			)
				begin
					select 'Изделие '+@item+' уже было выдано под этот заказ' as [error]
						, 'Изделие '+@item+' уже было выдано под этот заказ' as answer
					return 3
				end
		end

	if ( @itemqty > 0 and substring(@orderno,1,1)='K' and exists (select * from [dbo].[imsul_otvhr] 
	where o_item_id=@imast_id and o_orderno_id=@orderno_id and o_serno_id<>@sernofrom_id) )
		begin
			select 'Изделие уже выдавалось под заказ "' + rtrim(@orderno) + '" из другой партии.' as answer
			return 3
		end

	--podzolov по согласованию с breslavetc. Жесткое распределение не используется. 2019/05/28

	--Жесткое распределение
	--select * from maxmast.nvall

	declare @osallqty float
	set @osallqty = 0 
	if isnull((select round(sum(nvall_allqty-nvall_issqty),@decimals)
						 from maxmast.nvall
						 where nvall_orderno=@orderno
							and nvall_lineno=@lineno
							and nvall_allqty<>nvall_issqty),0)>0--Заказ жестко распределен
		begin
			if (select round(sum(nvall_allqty-nvall_issqty),@decimals)
					from maxmast.nvall
					where nvall_orderno=@orderno
						and nvall_lineno=@lineno
						and nvall_bin=@frombin
						and nvall_serno=@sernofrom)>=@itemqty
				begin
					set @osallqty=@itemqty
				end 
			else 
				begin
					select 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Компонент жестко распределен. Введено слишком большое кол-во или неправильное место хранения.' as [error],'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Компонент жестко распределен. Введено слишком большое кол-во или неправильное место хранения.' as [answer]
					return 3
				end
		end 
		

	declare @raspred_orderno char(20)
	set @raspred_orderno=(select top 1 nvall_orderno from maxmast.nvall where nvall_item=@item and nvall_store=@fromstore and nvall_bin=@frombin and nvall_account=@fromacct and nvall_serno=@sernofrom)
	--Жесткое распределение конец
	

	if not exists(select nvbin_bin from maxmast.nvbin where nvbin_bin=@frombin)
		begin
			select
					'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не существует места хранения ['+@frombin+']' as [error]
				, 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не существует места хранения ['+@frombin+']' as [answer]
			return 3
		end

	if (@fromacct!='IMPER') and isnull((select round(imast_freestock,@decimals) from maxmast.imast where imast_item=@item),0)<@itemqty and (round(@osallqty,@decimals)=0)
	begin
		set @raspred_orderno = (select top 1 nvall_orderno from maxmast.nvall where nvall_item=@item and nvall_store=@fromstore and nvall_bin=@frombin and nvall_account=@fromacct and nvall_serno=@sernofrom)
		if ( @raspred_orderno is not null )
			select 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Данное изделие распределено под заказ '+@raspred_orderno as [error],'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Данное изделие распределено под заказ '+@raspred_orderno as [answer]
		else 
			select 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не достаточно запаса для данной строки' as [error],'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не достаточно запаса для данной строки' as [answer]
		return 3
	end

	if round(isnull((select imsul_balance-(case when @osallqty = 0 then imsul_osallqty else 0 end) 
	from maxmast.imsul 
		join maxmast.imsu on imsu_id=imsul_imsu_id
		join maxmast.imast on imast_id=imsu_item_id
		left join maxmast.nvbin on nvbin_id=imsul_nvbin_id
		join maxmast.nvsto on nvsto_id=imsul_store_id
		join maxmast.nvacc on nvacc_id=imsul_nvacc_id
	where  (imast_item=@item)
		and (nvsto_store=@fromstore)
		and (nvacc_account=@fromacct)
		and (ISNULL(nvbin_bin,'')=@frombin)
		and (imsu_serno=@sernofrom)),0),@decimals)<@itemqty
		begin
			select
					'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не достаточно запаса в партии' as [error]
				, 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Не достаточно запаса в партии ' as [answer]
			return 3
		end

	if @itemqty>0 and round(isnull((select mrcpt_dueqty from maxmast.mrcpt 
	where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno),0),@decimals)<cast(@itemqty as decimal(18,10))
		begin
			select
					'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Выдаваемое кол-во превосходит требуемое' as [error]
				, 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Выдаваемое кол-во превосходит требуемое' as [answer]
			return 3
		end

	if ( @itemqty<0 and -@itemqty>round(isnull((select mrcpt_issqty from maxmast.mrcpt 
	where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno),-1),@decimals) )
		begin
			select
					'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное' as [error]
				, 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное' as [answer]
			return 3
		end

	if ( @itemqty<0 and -@itemqty>round(isnull((select sum(nvtrn_qty) from maxmast.nvtrn with (readuncommitted) 
	where nvtrn_origin=@orderno and nvtrn_item_id=@imast_id and nvtrn_serno_id=@sernoto_id),-1),@decimals) )
		begin
			select
					'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное по данной партии' as [error]
				, 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Возвращаемое кол-во превосходит выданное по данной партии' as [answer]
			return 3
		end

	if ( @itemqty=0 )
		begin
			select
					'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Введено нулевое колличество' as [error]
				, 'Ошибка на строке ['+str(@lineno)+'] изделие ['+@item+'] Введено нулевое колличество' as [answer]
			return 3
		end

	--SET XACT_ABORT ON
	--begin tran tran1
	--DECLARE @sec int, @orderno char(10), @lineno int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float,@fromstore char(5),@fromacct char(5),@tostore char(5),@toacct char(5),@frombin char(15),@tobin char(15),@serno char(15),@item char(22),@itemqty float(8), @lui char(10), @curser char(15);
	--DECLARE @sec int, @time char(6),@dateday int,@timesec int,@str1 char(15),@str2 char(15),@daterec datetime, @average float,@stockuom char(5),@bal float, @parent varchar(22);
	--set @parent=(select mford_item from maxmast.mford where mford_orderno=@orderno)

	/**************%%%%%%%%%%%%%%%%%%%%%Перемещение%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	print('[nv00_all_complete]')
	declare @r int
	exec @r = [dbo].[nv00_all_complete]
								@fromstore,@fromacct,@tostore,@toacct,@frombin,@tobin
							, @item,@itemqty,@sernofrom,@sernoto,@lui,@remarks,@cost,'Wi','Wi'
							,@orderno,@lineno, '', 0, 0, '', '', '', @forwardid,@serial
			
	if ( @r <> 0 ) begin return 3 end
	/**************%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!!!!!!!!!!!!!!!!*/
	print('[nv00_all_complete] end')
	-----------------------------------------MRCPT----------------------
	print('MRCPT')
	if not exists(select * from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
		begin 
			--RAISERROR ('Ошибка...............', 16 ,1)
			select
					'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Отсутствует строка в таблице MRCPT' as [error]
				, 'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Отсутствует строка в таблице MRCPT' as [answer]
			--rollback tran tran1
			return 3
		end
	
	update maxmast.mrcpt
		set mrcpt_issqty = round(mrcpt_issqty + @itemqty,@decimals)
			, mrcpt_lud = convert(varchar(10), getdate(), 121)
			, mrcpt_lui = @lui
		
			, mrcpt_osallqty = mrcpt_osallqty - @osallqty
		where mrcpt_orderno_id = @orderno_id and mrcpt_lineno=@lineno

	if abs((select round(mrcpt_issqty-mrcpt_dueqty,@decimals) 
	from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno))<'0.0000001'
		begin
			update
				maxmast.mrcpt
			set
				mrcpt_issqty = 
--Изменил Бреславец 02,04,18 т.к. мы перемещаем округленное в большую сторону				
				round(mrcpt_dueqty,@decimals)--mrcpt_dueqty
			where
				mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno
		end

	if (select round(mrcpt_dueqty-mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)<0
		begin
			--select
			--		'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT' as [error]
			--	, 'Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT' as [answer]
			--rollback tran tran1
			declare @qty_over float=(select round(mrcpt_dueqty-mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			declare @qty_1 float=(select round(mrcpt_dueqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			declare @qty_2 float=(select round(mrcpt_issqty,@decimals) from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)
			select '*Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT (остаток:'+ltrim(str(@qty_over))+')' as [error]
			,'**Ошибка перемещения на строке ['+str(@lineno)+'] изделие ['+@item+'] Перерасход компонентов в таблице MRCPT '
			+cast(cast(@qty_over as numeric(10,8)) as char(20)) +cast(@qty_1 as CHAR(20))+cast(@qty_2 as CHAR(20)) as [answer]
			return 3
		end
		
	-----------------------------------------MRCPT_ITEMS---------------
	declare @mrcpt_id int
	set @mrcpt_id = 
	(
		select
			mrcpt_id
		from
			maxmast.mrcpt
		where
					mrcpt_orderno_id = @orderno_id
			and mrcpt_lineno = @lineno
	)

		exec [dbo].[nv15_set_mrcpt_items]
			@orderno = @orderno
		, @lineno = @lineno
		, @item = @item
		, @serno = @sernofrom
		, @itemqty = @itemqty

	-----------------------------------------MRCPT_COSTS----------------
/*	print('MRCPT_COSTS')
	exec [dbo].[caa_mrcpt_set_costs]
		@mrcpt_id = @mrcpt_id
	
	-----------------------------------------MFORD_COSTS---------------
	print('MFORD_COSTS')
	exec [dbo].[caa_mford_set_costs]
		@orderno = @orderno
	, @item = @item
	, @serno = @sernofrom
	, @itemqty = @itemqty
		
	-----------------------------------------MRQT----------------------
*/	print('MRQT')
	update
		maxmast.mrqt
	set
		mrqt_dueqty = round(mrqt_dueqty-@itemqty,@decimals)
	where
		mrqt_rqtserial = (select mrcpt_rqtserial from maxmast.mrcpt where mrcpt_orderno_id=@orderno_id and mrcpt_lineno=@lineno)

	-----------------------------------------IMAST_COMMIT---------------------
	print('IMAST')
	update maxmast.imast set 
	imast_commit=round(isnull((select sum(mrqt_dueqty) from maxmast.mrqt where mrqt_ordserial in (0,-1) and mrqt_item_id=@imast_id),0),@decimals)
	where (imast_item=@item)
	-----------------------------------------NVALL---------------------
	if ( @osallqty > 0 )
		begin
			update
				maxmast.nvall
			set
					nvall_issqty = round(nvall_issqty+@osallqty,@decimals)
				, nvall_lud = getdate()
				, nvall_lui = @lui 
		where
					nvall_orderno = @orderno
			and nvall_lineno = @lineno
			and nvall_bin = @frombin
			and nvall_serno = @sernofrom
			and nvall_store = @fromstore
			and nvall_account = @fromacct
		end
	--select * from maxmast.nvall
	--commit tran tran1
	if ( @showanswer = 0 )
		begin
			select ' ' as [error], 1 as answer
			return 0
		end
END
*/


