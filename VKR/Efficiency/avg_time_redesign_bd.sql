USE MAX101srl

declare @time table (time_begin datetime, time_end datetime, time_s_e int)
declare @t int = 0;
while @t < 100
begin
declare @d1 datetime = GetDate()

    select top 1000 * 
    from maxmast.puord 
    inner join maxmast.pulin on pulin_puord_id = puord_id 
    inner join maxmast.purel on purel_pulin_id = pulin_id 
    inner join maxmast.pugrn on pugrn_purel_id = purel_id

declare @d2 datetime = GetDate()
insert @time select @d1, @d2, datediff(millisecond, @d1, @d2)
set @t = @t + 1
end

select * from @time
declare @time_avg table (avg_time int)
insert into @time_avg
		select avg (time_s_e) from @time

select * from @time_avg

