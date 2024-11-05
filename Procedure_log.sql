-- COLOCAR O BANCO A SER UTILIZADO
USE [DB_TESTE_VAM]

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ALTERAR O NOME DA PROCEDURE
CREATE PROCEDURE [dbo].[Log_ProcedureCall]
					@ObjectID		INT,
					@DatabaseID		INT = NULL,
					@AdditionalInfo NVARCHAR(MAX) = NULL
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ProcedureName NVARCHAR(400);

	SELECT @DatabaseID = COALESCE(@DatabaseID, DB_ID())
			,@ProcedureName = COALESCE
								(
									QUOTENAME(DB_NAME(@DatabaseID)) + '.'
									+ QUOTENAME(OBJECT_SCHEMA_NAME(@ObjectID, @DatabaseID))
									+ '.' + QUOTENAME(OBJECT_NAME(@ObjectID, @DatabaseID)),
									ERROR_PROCEDURE()
								);
	-- ALTERAR NOME DO BANCO E DA TABELA
	INSERT [DB_TESTE_VAM].[dbo].[ProcedureLog]
		(
			DataBaseID,
			ObjectID,
			ProcedureName,
			ErrorLine,
			ErrorMessage,
			AdditionalInfo,
			UserExecute
		)
	SELECT
		@DatabaseID,
		@ObjectID,
		@ProcedureName,
		ERROR_LINE(),
		ERROR_MESSAGE(),
		@AdditionalInfo,
		ORIGINAL_LOGIN()
END