USE MAX101analiz

declare @time table (time_begin datetime, time_end datetime, time_s_e int)
declare @t int = 0;
while @t < 100
begin
declare @d1 datetime = GetDate()

    select top 1000 * 
    from maxmast.puord 
    inner join maxmast.pulin on pulin_orderno = puord_orderno 
    inner join maxmast.purel on purel_orderno = pulin_orderno and purel_ordline = pulin_ordline 
    inner join maxmast.pugrn on pugrn_orderno = purel_orderno and pugrn_ordline = purel_ordline and pugrn_release = purel_release

declare @d2 datetime = GetDate()
insert @time select @d1, @d2, datediff(millisecond, @d1, @d2)
set @t = @t + 1
end

select * from @time
declare @time_avg table (avg_time int)
insert into @time_avg
		select avg (time_s_e) from @time

select * from @time_avg

