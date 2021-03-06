USE [MAX101analiz]
GO
/****** Object:  StoredProcedure [maxmast].[RecursiveQuery]    Script Date: 16.12.2021 16:11:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [maxmast].[RecursiveQuery] AS
BEGIN
declare @t table (par int, det int, lev int)

insert @t select -1, 143137, 0

declare @lev int = 0

while @@ROWCOUNT > 0 and @lev < 50
begin
 set @lev = @lev + 1

 insert @t
 select distinct det, t_order_det, @lev
 from @t t1
  inner join zz_result_tree rt on rt.t_order_par = det
 where lev = @lev - 1

end

select t.*, mford_orderno 
from @t t 
 inner join maxmast.mford on mford_id = det

/*select t_order_det 
from zz_result_tree 
where t_order_par = 143137*/

/*select t1.t_order_det 
from zz_result_tree t1 
where t1.t_order_par in (select t2.t_order_det 
from zz_result_tree t2 
where t2.t_order_par = 143137)*/
END