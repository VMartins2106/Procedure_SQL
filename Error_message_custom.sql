USE [DB_TESTE_VAM]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [DBO].[PR_ERROR_MESSAGE_CUSTOM]
					@ErrorMessageCustom VARCHAR(4000)

AS
BEGIN
	BEGIN TRY

		DECLARE @ErrorSeverityCustom INT = ERROR_SEVERITY()
			,@ErrorStateCustom INT = ERROR_STATE();

		RAISERROR(@ErrorMessageCustom, @ErrorSeverityCustom, @ErrorStateCustom);

	END TRY

	BEGIN CATCH
		
		DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
			,@ErrorSeverity INT = ERROR_SEVERITY()
			,@ErrorState INT = ERROR_STATE();

		EXEC DB_TESTE_VAM.DBO.Log_ProcedureCall @ObjectID = @@PROCID

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

	END CATCH
END