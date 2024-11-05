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

CREATE PROCEDURE dbo.PR_DISPARO_AUTOMATICO
					@NomeTabela			VARCHAR(255)		-- Nome da tabela a ser utilizada
					,@TipoPublico		VARCHAR(50)			-- Determina o público
					,@TipoExecução		INT = 0				-- Padrão (0) : disparo de e-mail

					-- Exceção Saúde
					,@Concierge			INT = 0				-- Excluir público do saúde exclusivo (saúde prime)
					,@Mediservice		INT = 0				-- Não inclui mediservice por padrão  (saúde plus)

AS
BEGIN
	BEGIN TRY

		/* MANUAL DOS PARÂMETROS

			Tipo execução:

			- 0 = disparo de e-mail				(Padrão, enriquece apenas com e-mail)
			- 1 = disparo de e-mail + PUSH/SMS	(Enriquece com e-mail e telefone)
			- 2 = disparo de PUSH/SMS			(Enriquece apenas com telefone)

			Tipo público

			- BVP
			- VIDA
			- PREVI
			- BARE
			- AUTO
			- RE
			- CAPI
			- DENTAL
			- SAUDE
				-> @Concierge = 0		-- padrão: exclui público Concierge
				-> @Concierge = 0		-- padrão: inclui público Concierge
				-> @Mediservice = 0		-- padrão: não faz a inclusão do público Mediservice
				-> @Mediservice = 1		-- padrão: faz a inclusão do público Mediservice
			
			- MEDISERVICE
			- CONCIERGE
			- INSTITUCIONAL

		*/

		DECLARE @Publico VARCHAR(50) = LTRIM(RTRIM(@TipoPublico))

		IF(@TipoExecução = 0)
		BEGIN

			DECLARE @PreFiltros						NVARCHAR(1000) = 
					'SELECT	CPF			= CAST(CPF_CNPJ AS BIGINT)
							,ID_CLIENTE	= HASHBYTES(''SHA1'', RIGHT(''000000000000000''+CONVERT(VARCHAR(15),RTRIM(LTRIM(CPF_CNPJ))),15))
							,EMAIL		= CAST(NULL AS VARCHAR(150))
							,BOUNCE		= CAST(NULL AS INT)
							,ORIGEM		= CAST(''BANCO'' AS VARCHAR(30))
							,TP_PESSOA
					INTO	'+@NomeTabela+'
					FROM	[DB_CRM].[dbo].[TB_SEGURO_CLIENTE_PF_PJ]
					WHERE	DT_REF = SELECT(MAX(DT_REF)) FROM [DB_CRM].[dbo].[TB_SEGURO_CLIENTE_PF_PJ] WITH (NOLOCK))
					AND '+@Publico+' = ''1'''

			DECLARE @UpdateQueryPosFiltro			VARCHAR(5000) = ''

			DECLARE @PosFiltro						NVARCHAR(2000) = 
					'UPDATE		A
					SET			BOUNCE = 1
					FROM		'+@NomeTabela+' A
					LEFT JOIN [DB_CRM].[dbo].[TB_BOUNCE_TD] AS B
								ON	A.EMAIL = B.[EMAIL] COLLATE Latin1_General_CI_AS
					LEFT JOIN [DB_CRM].[dbo].[TB_CAMPANHA_HARD_BOUNCE] AS C
								ON	A.EMAIL = C.[EMAIL] COLLATE Latin1_General_CI_AS
					WHERE B.[EMAIL] IS NOT NULL OR A.EMAIL != C.[EMAIL] COLLATE Latin1_General_CI_AS
						
					UPDATE		A
					SET			A.EMAIL = B.EMAIL
					FROM		'+@NomeTabela+' A
					INNER JOIN	[DB_CRM].[dbo].[TB_CRM_EMAIL]	B
					ON			A.CPF	= CAST(B.CPF_CNPJ AS BIGINT)
					WHERE		A.EXCLUIR IS NULL
					'
					+@UpdateQueryPosFiltro+
					'
					UPDATE		A
					SET			A.EMAIL = B.EMAIL
					FROM		'+@NomeTabela+' A
					INNER JOIN	[DB_CRM].[dbo].[TB_DADOS_BASICOS]	B (NOLOCK)
					ON			A.CPF	= CAST(B.CCPF_CNPJ AS BIGINT)
					WHERE		A.EXCLUIR	IS NULL
					AND			A.EMAIL		IS NULL
					AND			A.TP_PESSOA = ''J''

					UPDATE		'+@NomeTabela+'
					SET			EXCLUIR = ''SEM EMAIL''
					WHERE		EMAIL IS NULL
					AND			EXCLUIR IS NULL

					UPDATE		'+@NomeTabela+'
					SET			EXCLUIR = ''EMAIL CORPORATIVO''
					WHERE		EMAIL LIKE ''%@%BANCO%'' COLLATE Latin1_General_CI_AS
					AND			EXCLUIR IS NULL

					UPDATE		'+@NomeTabela+'
					SET			EXCLUIR = ''BOUNCE''
					WHERE		BOUNCE	= 1
					AND			EXCLUIR IS NULL

					DELETE	A
					FROM	(SELECT *, ROWID = ROW_NUMBER() OVER (PARTITION BY CPF ORDER BY NEWID())
							FROM '+@NomeTabela+') A
					WHERE ROWID > 1

					DELETE	A
					FROM	(SELECT *, ROWID = ROW_NUMBER() OVER (PARTITION BY EMAIL ORDER BY NEWID())
							FROM '+@NomeTabela+') A
					WHERE ROWID > 1
					AND EMAIL IS NOT NULL'

			DECLARE @CondicaoWhereContagem1			VARCHAR(500) = 'WHERE TP_PESSOA = ''F'''
			DECLARE @CondicaoWhereContagem2			VARCHAR(500) = 'WHERE EXCLUIR IS NOT NULL AND TP_PESSOA = ''F'''
			DECLARE @CondicaoWhereContagem3			VARCHAR(500) = 'WHERE EXCLUIR IS NULL AND TP_PESSOA = ''F'''
			DECLARE @CondicaoWhereContagem4			VARCHAR(500) = 'WHERE TP_PESSOA = ''J'''
			DECLARE @CondicaoWhereContagem5			VARCHAR(500) = 'WHERE EXCLUIR IS NOT NULL AND TP_PESSOA = ''J'''
			DECLARE @CondicaoWhereContagem6			VARCHAR(500) = 'WHERE EXCLUIR IS NULL AND TP_PESSOA = ''J'''

			DECLARE @NomeContagem1					VARCHAR(300) = 'PUBLICO INICIAL '+@Publico+' PF'' AS ''FILTRO'', COUNT(*) ''PF'''
			DECLARE @NomeContagem2					VARCHAR(300) = 'PUBLICO INICIAL '+@Publico+' PJ'' AS ''FILTRO'', COUNT(*) ''PJ'''

			DECLARE @QueryContagem					VARCHAR(5000)=
					'SELECT '+@NomeContagem1+'
					FROM '+@NomeTabela+'
					'+@CondicaoWhereContagem1+'
					UNION ALL
					SELECT EXCLUIR, COUNT(*) AS ''QTD''
					FROM '+@NomeTabela+'
					'+@CondicaoWhereContagem2+'
					GROUP BY EXCLUIR
					UNION ALL
					SELECT FILTRO = ''PUBLICO FINAL'', COUNT(*) AS ''QTD''
					FROM '+@NomeTabela+'
					'+@CondicaoWhereContagem3+'
					
					SELECT '+@NomeContagem2+'
					FROM '+@NomeTabela+'
					'+@CondicaoWhereContagem4+'
					UNION ALL
					SELECT EXCLUIR, COUNT(*) AS ''QTD''
					FROM '+@NomeTabela+'
					'+@CondicaoWhereContagem5+'
					GROUP BY EXCLUIR
					UNION ALL
					SELECT FILTRO = ''PUBLICO FINAL'', COUNT(*) AS ''QTD''
					FROM '+@NomeTabela+'
					'+@CondicaoWhereContagem6
			
			IF(@Publico != '' AND (@Publico  = 'BVP' OR @Publico  = 'VIDA' OR @Publico  = 'PREVI' OR @Publico  = 'BARE' OR @Publico  = 'AUTO' OR @Publico  = 'RE' OR @Publico  = 'SAUDE' OR @Publico  = 'CAPI' OR @Publico  = 'DENTAL'))
			BEGIN
				EXEC(@PreFiltros)

				IF(@Publico = 'BVP')
				BEGIN
					EXEC dbo.PR_FILTROS_BASICOS_EXCLUSAO @NomeTabela, 'CPF'
					EXEC(@PosFiltro)
					EXEC(@QueryContagem)
				END

				ELSE IF(@Publico = 'VIDA')
				BEGIN
					PRINT @Publico
				END

				ELSE IF(@Publico = 'PREVI')
				BEGIN
					PRINT @Publico
				END

				ELSE IF(@Publico = 'BARE')
				BEGIN
					PRINT @Publico
				END

				ELSE IF(@Publico = 'AUTO')
				BEGIN
					PRINT @Publico
				END

				ELSE IF(@Publico = 'RE')
				BEGIN
					PRINT @Publico
				END

				ELSE IF(@Publico = 'CAPI')
				BEGIN
					PRINT @Publico
				END

				ELSE IF(@Publico = 'DENTAL')
				BEGIN
					PRINT @Publico
				END

				ELSE IF(@Publico = 'SAUDE')
				BEGIN

					IF(@Mediservice = 1)
					BEGIN
						EXEC( 
							'INSERT INTO '+@NomeTabela+'
							SELECT DISTINCT
									NR_CPF_CNPJ
									,ID_CLIENTE = HASHBYTES(''SHA1'', RIGHT(''000000000000000''+CONVERT(VARCHAR(15),RTRIM(LTRIM(NR_CPF_CNPJ))),15))
									,NULL
									,NULL
									,''MEDISERVICEPF''
									,NULL
							FROM	[DB_CRM].[dbo].[TB_CLIENTE_MED_PF]
							WHERE	DT_REF = (SELECT MAX(DT_REF) FROM [DB_CRM].[dbo].[TB_CLIENTE_MED_PF] WITH (NOLOCK)
							AND TRY_CAST(CPF AS BIGINT) IS NOT NULL

							DELETE	A
							FROM	(SELECT *, ROWID = ROW_NUMBER() OVER (PARTITION BY IIF(ORIGEM = ''MEDISERVICEPF'', 0, 1)
									FROM '+@NomeTabela+') A
							WHERE ROWID > 1
							AND EMAIL IS NOT NULL

							CREATE INDEX IDX01 ON '+@NomeTabela+' (CPF)

							INSERT INTO '+@NomeTabela+'
							SELECT DISTINCT
									NR_CPF_CNPJ_FILIAL
									,ID_CLIENTE = HASHBYTES(''SHA1'', RIGHT(''000000000000000''+CONVERT(VARCHAR(15),RTRIM(LTRIM(NR_CPF_CNPJ_FILIAL))),15))
									,NULL
									,NULL
									,''MEDISERVICEPJ''
									,NULL
							FROM	[DB_CRM].[dbo].[TB_CLIENTE_MED_PJ]
							WHERE	DT_REF = (SELECT MAX(DT_REF) FROM [DB_CRM].[dbo].[TB_CLIENTE_MED_PJ] WITH (NOLOCK)
							AND TRY_CAST(CNPJ AS BIGINT) IS NOT NULL

							DELETE	A
							FROM	(SELECT *, ROWID = ROW_NUMBER() OVER (PARTITION BY IIF(ORIGEM = ''MEDISERVICEPJ'', 0, 1)
									FROM '+@NomeTabela+') A
							WHERE ROWID > 1
							AND EMAIL IS NOT NULL

							CREATE INDEX IDX02 ON '+@NomeTabela+' (CPF)')

						SET @CondicaoWhereContagem1 = 'WHERE ORIGEM = ''BRADESCO'''
						SET @CondicaoWhereContagem2 = 'WHERE EXCLUIR IS NOT NULL AND ORIGEM = ''BRADESCO'''
						SET @CondicaoWhereContagem3 = 'WHERE EXCLUIR IS NULL AND ORIGEM = ''BRADESCO'''
						SET @CondicaoWhereContagem4 = 'WHERE ORIGEM = ''MEDISERVICEPF'' OR ORIGEM = ''MEDISERVICEPJ'''
						SET @CondicaoWhereContagem5 = 'WHERE EXCLUIR IS NOT NULL AND (ORIGEM = ''MEDISERVICEPF'' OR ORIGEM = ''MEDISERVICEPJ'')'
						SET @CondicaoWhereContagem6 = 'WHERE EXCLUIR IS NULL AND (ORIGEM = ''MEDISERVICEPF'' OR ORIGEM = ''MEDISERVICEPJ'')'

						SET @NomeContagem1			= 'PUBLICO INICIAL SAUDE AS ''FILTRO'', COUNT(*) AS QTD'
						SET @NomeContagem2			= 'PUBLICO INICIAL MED AS ''FILTRO'', COUNT(*) AS QTD'
					END

					EXEC dbo.PR_FILTROS_BASICOS_EXCLUSAO @NomeTabela, 'CPF'

					IF(@Concierge = 0)
					BEGIN
						SET @UpdateQueryPosFiltro		= 
							'UPDATE		A
							SET			EXCLUIR = ''CONCIERGE''
							FROM '+@NomeTabela+' A
							INNER JOIN	[DB_CRM].[dbo].[TB_CONCIERGE]	B
							ON			CAST(A.CPF AS BIGINT) = CAST([DB_CRM].[dbo].[TB_RECUPERA_NUMEROS](B.CPF) AS BIGINT)
							WHERE		EXCLUIR IS NULL'
					END

					EXEC(@PosFiltro)
					EXEC(@QueryContagem)

				END
			END

			ELSE IF(@Publico = 'MEDISERVICE')
			BEGIN
				SET @NomeContagem1			= 'PUBLICO INICIAL '+@Publico+' PF'' AS ''FILTRO'', COUNT(*) AS ''PF'''
				SET @NomeContagem2			= 'PUBLICO INICIAL '+@Publico+' PJ'' AS ''FILTRO'', COUNT(*) AS ''PJ'''

				SET @CondicaoWhereContagem1 = 'WHERE TP_PESSOA = ''F'''
				SET @CondicaoWhereContagem2 = 'WHERE EXCLUIR IS NOT NULL AND TP_PESSOA = ''F'''
				SET @CondicaoWhereContagem3 = 'WHERE EXCLUIR IS NULL AND TP_PESSOA = ''F'''
				SET @CondicaoWhereContagem4 = 'WHERE TP_PESSOA = ''J'''
				SET @CondicaoWhereContagem5 = 'WHERE EXCLUIR IS NOT NULL AND TP_PESSOA = ''J'''
				SET @CondicaoWhereContagem6 = 'WHERE EXCLUIR IS NULL AND TP_PESSOA = ''J'''

				EXEC( 
					'SELECT	CPF			= CAST(NR_CPF_CNPJ AS BIGINT)
							,ID_CLIENTE	= HASHBYTES(''SHA1'', RIGHT(''000000000000000''+CONVERT(VARCHAR(15),RTRIM(LTRIM(NR_CPF_CNPJ))),15))
							,EMAIL		= CAST(NULL AS VARCHAR(150))
							,BOUNCE		= CAST(NULL AS INT)
							,ORIGEM		= CAST(''F'' AS VARCHAR(30))
							,TP_PESSOA
					INTO	'+@NomeTabela+'
					FROM	[DB_CRM].[dbo].[TB_CLIENTE_MED_PF]
					WHERE	DT_REF = (SELECT MAX(DT_REF) FROM [DB_CRM].[dbo].[TB_CLIENTE_MED_PF] WITH (NOLOCK)
					AND TRY_CAST(CPF AS BIGINT) IS NOT NULL							
						
					DELETE	A
					FROM	(SELECT *, ROWID = ROW_NUMBER() OVER (PARTITION BY IIF(TP_PESSOA = ''F'', 0, 1)
							FROM '+@NomeTabela+') A
					WHERE ROWID > 1
					AND EMAIL IS NOT NULL

					CREATE INDEX IDX01 ON '+@NomeTabela+' (CPF)

					INSERT INTO '+@NomeTabela+'
					SELECT DISTINCT
							NR_CPF_CNPJ_FILIAL
							,ID_CLIENTE = HASHBYTES(''SHA1'', RIGHT(''000000000000000''+CONVERT(VARCHAR(15),RTRIM(LTRIM(NR_CPF_CNPJ_FILIAL))),15))
							,NULL
							,NULL
							,''J''
					FROM	[DB_CRM].[dbo].[TB_CLIENTE_MED_PJ]
					WHERE	DT_REF = (SELECT MAX(DT_REF) FROM [DB_CRM].[dbo].[TB_CLIENTE_MED_PJ] WITH (NOLOCK)
					AND TRY_CAST(CNPJ AS BIGINT) IS NOT NULL

					DELETE	A
					FROM	(SELECT *, ROWID = ROW_NUMBER() OVER (PARTITION BY IIF(TP_PESSOA = ''J'', 0, 1)
							FROM '+@NomeTabela+') A
					WHERE ROWID > 1
					AND EMAIL IS NOT NULL

					CREATE INDEX IDX02 ON '+@NomeTabela+' (CPF)')

				EXEC dbo.PR_FILTROS_BASICOS_EXCLUSAO @NomeTabela, 'CPF'

				IF(@Concierge = 0)
				BEGIN
					SET @UpdateQueryPosFiltro		= 
						'UPDATE		A
						SET			EXCLUIR = ''CONCIERGE''
						FROM '+@NomeTabela+' A
						INNER JOIN	[DB_CRM].[dbo].[TB_CONCIERGE]	B
						ON			CAST(A.CPF AS BIGINT) = CAST([DB_CRM].[dbo].[TB_RECUPERA_NUMEROS](B.CPF) AS BIGINT)
						WHERE		EXCLUIR IS NULL'
				END

				EXEC(@PosFiltro)
				EXEC(@QueryContagem)

			END

			ELSE IF(@Publico = 'CONCIERGE')
			BEGIN
				EXEC('SELECT	CPF			= CAST(CPF_CNPJ AS BIGINT)
							,ID_CLIENTE	= HASHBYTES(''SHA1'', RIGHT(''000000000000000''+CONVERT(VARCHAR(15),RTRIM(LTRIM(CPF_CNPJ))),15))
							,EMAIL		= CAST(NULL AS VARCHAR(150))
							,BOUNCE		= CAST(NULL AS INT)
							,TP_PESSOA
					INTO	'+@NomeTabela+'
					FROM	[DB_CRM].[dbo].[TB_SEGURO_CLIENTE_PF_PJ]
					WHERE	DT_REF = SELECT(MAX(DT_REF)) FROM [DB_CRM].[dbo].[TB_SEGURO_CLIENTE_PF_PJ] WITH (NOLOCK))
					AND SAUDE = 1')

				EXEC dbo.PR_FILTROS_BASICOS_EXCLUSAO @NomeTabela, 'CPF'

				SET @UpdateQueryPosFiltro =
					'UPDATE		A
					SET			EXCLUIR = ''CONCIERGE''
					FROM		'+@NomeTabela+' A
					INNER JOIN	DB_CRM.dbo.TB_SAU_CLIENTES	B
					ON			CAST(A.CPF AS BIGINT) = CAST(DB_SECUNDARIA.dbo_FNCRECUPERA_NUMEROS(B.CPF) AS BIGINT)'

				EXEC(@PosFiltro)

				EXEC('UPDATE	A
					SET			A.EMAIL = B.EMAIL_SEGURADO
					FROM		'+@NomeTabela+' A
					INNER JOIN	DB_CRM.dbo.TB_SAU_CLIENTES	B
					ON			A.CPF = CAST(B.CPF AS BIGINT)
					WHERE		A.EMAIL IS NULL
				
					UPDATE		A
					SET			EXCLUIR = '' NÃO CONCIERGE''
					FROM		'+@NomeTabela+' A
					WHERE		EXCLUIR IS NULL')

				EXEC('SELECT ''PUBLICO INICIAL CONCIERGE'' PF, COUNT(*) AS QTD
					FROM '+@NomeTabela+'
					WHERE TP_PESSOA = ''F''
					UNION ALL
					SELECT EXCLUIR, COUNT(*)
					FROM '+@NomeTabela+'
					WHERE EXCLUIR IS NOT NULL AND TP_PESSOA = ''F''
					GROUP BY EXCLUIR
					UNION ALL
					SELECT FILTRO = ''PUBLICO FINAL'', COUNT(*) AS ''QTD''
					FROM '+@NomeTabela+'
					WHERE EXCLUIR = ''CONCIERGE'' AND TP_PESSOA = ''F''
					
					SELECT ''PUBLICO INICIAL CONCIERGE'' PJ, COUNT(*) AS QTD
					FROM '+@NomeTabela+'
					WHERE TP_PESSOA = ''J''
					UNION ALL
					SELECT EXCLUIR, COUNT(*)
					FROM '+@NomeTabela+'
					WHERE EXCLUIR IS NOT NULL AND TP_PESSOA = ''J''
					GROUP BY EXCLUIR
					UNION ALL
					SELECT FILTRO = ''PUBLICO FINAL'', COUNT(*) AS ''QTD''
					FROM '+@NomeTabela+'
					WHERE EXCLUIR = ''CONCIERGE'' AND TP_PESSOA = ''J''
			END

			ELSE IF(@Publico = 'INSTITUCIONAL')
			BEGIN
				PRINT @Publico
			END
			
			ELSE
			BEGIN
				EXEC DB_TESTE_VAM.[dbo].[PR_ERROR_MESSAGE_CUSTOM] 
					'O público informado não é válido. Utilize uma destas opções: ''BVP'', ''VIDA'', ''PREVI'', ''BARE'', ''AUTO'', ''RE'', ''SAUDE'', ''CAPI'', ''DENTAL'', ''INSTITUCIONAL'''
			END

		END

	END TRY

	BEGIN CATCH
		
		DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
			,@ErrorSeverity INT = ERROR_SEVERITY()
			,@ErrorState INT = ERROR_STATE();

		EXEC DB_TESTE_VAM.DBO.Log_ProcedureCall @ObjectID = @@PROCID

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

	END CATCH
END