-- COLOCAR O BANCO A SER UTILIZADO
USE DB_TESTE_VAM

CREATE TABLE DB_TESTE_VAM.[dbo].[ProcedureLog](
	LogDate smallDateTime, 
	DataBaseID int,
	ObjectID int,
	ProcedureName NVARCHAR(400),
	ErrorLine int,
	ErrorMessage NVARCHAR,
	AdditionalInfo NVARCHAR,
	UserExecute VARCHAR(50)
);