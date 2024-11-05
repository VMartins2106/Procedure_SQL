USE [DB_TESTE_VAM]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*************************************************************************************

Autor:			Victor Martins
Data:			31/10/2024 - dd/mm/yyyy
Objetivo:		Executar scripts de divisão de público mais fácil e rápido

*************************************************************************************/

CREATE PROCEDURE dbo.PR_FILTROS_BASICOS_EXCLUSAO
					@NomeTabela			VARCHAR(255)		
					,@CampoChave			VARCHAR(50)		

AS
BEGIN
	BEGIN TRY
		PRINT('PROC FILTRO OK')
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
			,@ErrorSeverity INT = ERROR_SEVERITY()
			,@ErrorState INT = ERROR_STATE();

		EXEC DB_TESTE_VAM.DBO.Log_ProcedureCall @ObjectID = @@PROCID

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
	END CATCH
END