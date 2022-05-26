USE [MAX101srl]
GO
/** Object:  StoredProcedure [dbo].[iems_process_save_data_PMV03_01_04_A]    Script Date: 12.05.2022 18:48:25 **/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--IT00115188            
--exec [dbo].[iems_process_save_data_PMV03_01_04_A] 'D06B6F74-7B53-41CE-8445-CE1E03E2CB58'
ALTER proc [dbo].[iems_process_save_data_PMV03_01_04_A] 
	@process_id varchar(50) = '56197D45-8EC0-4302-9973-2B88E1584551'--'276794E2-B93B-42FD-9C4D-S10E05A5684B3'
as
begin
	--return

	declare @json varchar(max) = 
			( 
				select [output] 
				from maxmast.iems_process 
				where uuid = @process_id 
			)

			--select @json

		--select * from maxmast.iems_process 

		declare @json_array varchar(max) = substring(@json, charindex('[', @json) + 1, charindex(']', @json) - charindex('[', @json) - 1)

	--select @json_Sarray

	declare @t table (
		t_id varchar(50)
		, t_storage varchar(50)
	)



		declare  @cur_location int = 0 
		, @charindex1_begin int
		, @charindex1 int
		, @charindex2 int
		, @charindex_block_begin int = 0
		, @charindex_block_end int = 0
		, @charindex_block_cur int = 0

		declare @cur_step int = 0

		declare @fields table(f_id int, f_name varchar(30), f_value varchar(300))
		insert into @fields (f_id, f_name)
		select 1, '"id"'
		union 
		select 2, '"storage"'


		declare @field_count int = ( select count(*) from @fields )
		declare @cur_field_id int = 0, @cur_field_name varchar(50), @cur_field_value varchar(500)
		declare @cur_block varchar(max) = ''
		declare @charindex2_2 int = 0 


	while (charindex('"id"', @json_array, @cur_location) > 0) and @cur_step < 5
	begin
		set @cur_field_id = 1
		set @charindex_block_begin = charindex('{', @json_array, @charindex_block_begin)
		set @charindex_block_end = charindex('}', @json_array, @charindex_block_begin)
		set @cur_block = substring(@json_array, @charindex_block_begin, @charindex_block_end - @charindex_block_begin)
		while @cur_field_id <= @field_count
		begin
			set @cur_field_name = (select f_name from @fields where f_id = @cur_field_id)
			print '@cur_field_name = ' + @cur_field_name
			set @charindex1_begin = charindex(@cur_field_name, @cur_block) 
			set @charindex1 = @charindex1_begin + len(@cur_field_name)
			set @charindex1 = charindex(':', @cur_block, @charindex1) + 1

			set @charindex2 = charindex(',', @cur_block, @charindex1)
			--set @charindex2_2 = charindex('}', @json_array, @charindex1)
			if (@charindex2 > @charindex_block_end) or (@charindex2 = 0)
			begin
				set @charindex2 = @charindex_block_end
			end
			--select @charindex1, @charindex2
			if (@charindex1_begin <= 0 ) or (@charindex1 > @charindex_block_end)
			begin
				set @cur_field_value = ''
			end
			else
			begin
				set @cur_field_value = substring(@cur_block, @charindex1, @charindex2 - @charindex1)
			end
			--select @cur_field_value	
			if charindex('"', @cur_field_value) > 0
			begin
				set @cur_field_value = ltrim(rtrim(replace(@cur_field_value, '"', '' )))
			end

		

			--set @cur_field_value = ltrim(rtrim(replace(@cur_field_value, ':', '' )))
			update @fields 
				set f_value = @cur_field_value
			where f_id = @cur_field_id
			set @cur_field_id = @cur_field_id + 1
		



		end

		insert into @t(
			t_id
			, t_storage
		)
			select (select f_value from @fields where f_id = 1)
				, (select f_value from @fields where f_id = 2)
	
	

		set @cur_location = @charindex_block_end--@charindex2
		set @charindex_block_begin = @charindex_block_end + 1
		set @cur_step = @cur_step + 1

	end



	declare @id varchar(50), @storage varchar(50)
	declare c cursor for 
		select distinct t_id
			, t_storage
		from @t
		where t_id<>'00000000-0000-0000-0000-000000000000'
		and t_storage<>''
		order by t_id

	open c 
	fetch next from c into @id, @storage

	while @@FETCH_STATUS = 0
	begin
		declare @login varchar(50) = 'carbone'
		declare @palletID varchar(50) = @id
		declare @destinationID varchar(50) = @storage

		exec [dbo].[iems_replace_tara_with_components] 
			@run_id = -1
			, @tara_name = @palletID
			, @tobin_guid = @destinationID
			, @login = @login

		fetch next from c into @id, @storage
	end

	close c
	deallocate c

end
