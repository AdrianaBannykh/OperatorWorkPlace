USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[correct_GUID_of_imsu]    Script Date: 13.05.2022 18:09:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[correct_GUID_of_imsu] '7CF10951-0871-484E-ABBD-949D39A88566'
ALTER PROCEDURE [dbo].[correct_GUID_of_imsu]  
    @imsu_GUID varchar(100)   
AS   

    SET NOCOUNT ON;  

select	imsu_GUID
		from maxmast.imsu
	where imsu_GUID = @imsu_GUID
 


