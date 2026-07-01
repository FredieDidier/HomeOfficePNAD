# =============================================================================
# build_dictionary.R
# Generates the variable dictionary for main_data.RData as an Excel file.
# Output: dictionary/variable_dictionary.xlsx
# =============================================================================

library(openxlsx)
library(here)

# ---- Variable definitions ---------------------------------------------------

dict <- data.frame(stringsAsFactors = FALSE,
                   
                   variable_name = c(
                     # Panel identifiers
                     "id_rs3", "id_dom", "id_panel", "panel_matched",
                     # Time
                     "Ano", "Trimestre", "year_quarter", "V1016",
                     # Survey design
                     "UF", "UPA", "V1008", "V1014", "V1028", "posest",
                     # Demographics — raw PNADC
                     "V2007", "V2009", "V2010", "V2005", "V1022",
                     # Demographics — datazoom.social
                     "faixa_idade", "regiao", "sigla_uf",
                     # Education
                     "VD3004", "VD3005", "faixa_educ",
                     # Labor market — raw PNADC
                     "VD4001", "VD4002", "VD4009",
                     # Labor market — datazoom.social
                     "ocupado", "forca_trab", "formal", "informal",
                     # Employment status outcomes — project-derived (full sample)
                     "in_labor_force", "employed", "unemployed",
                     # Income
                     "VD4019", "Habitual", "rendimento_habitual_real",
                     # Hours
                     "VD4031", "VD4035",
                     # Home office
                     "V4022", "home_office",
                     # Sector and occupation
                     "V4013", "V4010", "cnae_2dig", "cod_2dig",
                     # Maternity leave
                     "V4006A", "on_maternity_leave",
                     # Project-specific treatment variables
                     "is_head_or_spouse",
                     "has_child_u4", "has_child_u4_no_gc", "has_child_u4_no_sc",
                     "has_child_5_7", "has_child_5_7_no_gc", "has_child_5_7_no_sc",
                     "age_youngest_child", "age_youngest_child_no_gc", "age_youngest_child_no_sc",
                     "potential_telework",
                     "treated",
                     "post_mp", "post_mp_alt",
                     "treat_x_post", "treat_x_post_alt",
                     "clt_private"
                   ),
                   
                   source = c(
                     "datazoom.social", "Project-derived", "Project-derived", "Project-derived",
                     "PNADC raw", "PNADC raw", "Project-derived", "PNADC raw",
                     "PNADC raw", "PNADC raw", "PNADC raw", "PNADC raw", "PNADC raw", "PNADC raw",
                     "PNADC raw", "PNADC raw", "PNADC raw", "PNADC raw", "PNADC raw",
                     "datazoom.social", "datazoom.social", "datazoom.social",
                     "PNADC raw", "PNADC raw", "datazoom.social",
                     "PNADC raw", "PNADC raw", "PNADC raw",
                     "datazoom.social", "datazoom.social", "datazoom.social", "datazoom.social",
                     "Project-derived", "Project-derived", "Project-derived",
                     "PNADC raw", "PNADC raw", "datazoom.social",
                     "PNADC raw", "PNADC raw",
                     "PNADC raw", "datazoom.social",
                     "PNADC raw", "PNADC raw", "datazoom.social", "datazoom.social",
                     "PNADC raw", "Project-derived",
                     "Project-derived",
                     "Project-derived", "Project-derived", "Project-derived",
                     "Project-derived", "Project-derived", "Project-derived",
                     "Project-derived", "Project-derived", "Project-derived",
                     "Project-derived",
                     "Project-derived",
                     "Project-derived", "Project-derived",
                     "Project-derived", "Project-derived",
                     "Project-derived"
                   ),

                   type = c(
                     "character", "character", "character", "integer",
                     "integer", "integer", "integer", "integer",
                     "integer", "character", "integer", "integer", "numeric", "integer",
                     "integer", "integer", "integer", "integer", "integer",
                     "character", "character", "character",
                     "integer", "integer", "character",
                     "integer", "integer", "integer",
                     "integer", "integer", "integer", "integer",
                     "integer", "integer", "integer",
                     "numeric", "numeric", "numeric",
                     "numeric", "numeric",
                     "integer", "integer",
                     "integer", "integer", "character", "character",
                     "integer", "integer",
                     "integer",
                     "integer", "integer", "integer",
                     "integer", "integer", "integer",
                     "numeric", "numeric", "numeric",
                     "integer",
                     "integer",
                     "integer", "integer",
                     "integer", "integer",
                     "integer"
                   ),

                   description_pt = c(
                     "Identificador avançado (Estágio 3) do indivíduo no painel rotativo, gerado pelo datazoom.social via load_pnadc(panel = \"advanced_3\"). Conecta a mesma pessoa entre trimestres usando data de nascimento doada, número de ordem no domicílio e correspondência difusa (fuzzy matching) por Teoria dos Grafos para entrevistas fragmentadas. NA quando o indivíduo não pôde ser pareado entre trimestres.",
                     "Identificador do domicílio, tornado globalmente único como string composta \"<V1014>_<id>\" (derivado do id_dom do datazoom, que é único apenas DENTRO de cada grupo de rotação V1014). Usado como variável de clusterização nas especificações principais. Ver nota de correção do build no CLAUDE.md.",
                     "Identificador de painel para uso em efeitos fixos (feols(... | id_panel)). Igual a id_rs3 quando o pareamento foi bem-sucedido (panel_matched==1); quando id_rs3 é NA, recebe um ID único por linha (prefixo 'unmatched_'), evitando que indivíduos diferentes não pareados sejam agrupados no mesmo efeito fixo espúrio.",
                     "=1 se id_rs3 não é NA, ou seja, se o indivíduo foi pareado com sucesso entre trimestres pelo algoritmo Estágio 3 (Teoria dos Grafos). =0 caso contrário (id_panel é um ID único por linha).",
                     "Ano da entrevista",
                     "Trimestre da entrevista (1=jan-mar, 2=abr-jun, 3=jul-set, 4=out-dez)",
                     "Identificador temporal numérico (Ano × 10 + Trimestre). Ex: 20221 = 1º tri 2022",
                     "Rodada da entrevista no painel rotativo (1 a 5 entrevistas consecutivas)",
                     "Código numérico da Unidade da Federação (IBGE)",
                     "Unidade Primária de Amostragem (setor censitário ou agrupamento)",
                     "Número de seleção do domicílio na UPA",
                     "Grupo de rotação do painel (painéis 6 a 13 nos dados disponíveis)",
                     "Peso amostral pós-estratificação (peso calibrado)",
                     "Estrato para estimação da variância amostral",
                     "Sexo (1=masculino, 2=feminino)",
                     "Idade em anos completos",
                     "Cor ou raça (1=branca, 2=preta, 3=amarela, 4=parda, 5=indígena)",
                     "Condição no domicílio. Códigos PNADC: 01=pessoa responsável, 02=cônjuge/companheiro(a) sexo diferente, 03=cônjuge/companheiro(a) mesmo sexo, 04=filho(a) do responsável E do cônjuge, 05=filho(a) somente do responsável, 06=enteado(a), 07=genro/nora, 08=pai/mãe/padrasto/madrasta, 09=sogro(a), 10=neto(a), 11=bisneto(a), 12=irmão/irmã, 13=avô/avó, 14=outro parente, 15=agregado(a) (não compartilha despesas), 16=convivente (compartilha despesas), 17=pensionista, 18=empregado(a) doméstico(a), 19=parente do(a) empregado(a) doméstico(a).",
                     "Situação do domicílio (1=urbana, 2=rural)",
                     "Grupo de faixa etária, derivado de V2009 (idade em anos) pelo datazoom.social. Categorias: 'Entre 14 e 17 anos', 'Entre 18 e 24 anos', 'Entre 25 e 29 anos', 'Entre 30 e 39 anos', 'Entre 40 e 49 anos', 'Entre 50 e 59 anos', '60 anos ou mais'.",
                     "Região geográfica (Norte, Nordeste, Sudeste, Sul, Centro-Oeste)",
                     "Sigla da Unidade da Federação (ex: SP, RJ, MG)",
                     "Nível de instrução mais elevado que frequentou ou concluiu (escala 1–7)",
                     "Anos de estudo (equivalente a anos de escolaridade)",
                     "Grupo de nível de instrução, derivado de VD3004 (nível de instrução mais elevado) pelo datazoom.social. Categorias: VD3004=1 → 'Sem instrução'; VD3004=2 → '1 a 7 anos de estudo'; VD3004=3 → '8 a 11 anos de estudo'; VD3004∈{4,5,6} → '9 a 14 anos de estudo'; VD3004=7 → '15 ou mais anos de estudo'.",
                     "Condição de atividade na semana de referência (1=força de trabalho, 2=fora da força de trabalho)",
                     "Condição de ocupação (1=ocupado, 2=desocupado)",
                     "Posição na ocupação no trabalho principal (1=empregado privado com carteira, 2=empregado privado sem carteira, 3=trabalhador doméstico com carteira, 4=trabalhador doméstico sem carteira, 5=empregado público com carteira, 6=empregado público sem carteira, 7=militar e servidor estatutário, 8=empregador, 9=conta-própria, 10=trabalhador familiar auxiliar). clt_private = (VD4009==1).",
                     "Indicador de ocupação (=1 se VD4002==1)",
                     "Indicador de participação na força de trabalho (=1 se VD4001==1)",
                     "Emprego formal. =1 inclui: empregados com carteira (privado, doméstico, público), militares/estatutários, E conta própria (VD4009=9) que contribui para a previdência (INSS). Empregadores (VD4009=8) ficam como nem formal nem informal (formal=0 e informal=0), logo formal+informal != 1.",
                     "Emprego informal (empregado sem carteira, doméstico/público sem carteira, conta própria sem contribuição ao INSS, trabalhador familiar auxiliar). Empregadores não entram aqui.",
                     "Indicador de participação na força de trabalho (= forca_trab) como inteiro 0/1 sobre toda a amostra. Variável de desfecho.",
                     "Indicador de ocupação sobre TODA a amostra: =1 se na força de trabalho E ocupada, caso contrário 0 (fora da força de trabalho → 0). Usar esta, não `ocupado`, para o desfecho de emprego e taxas de emprego incondicionais.",
                     "Indicador de desemprego sobre TODA a amostra: =1 se na força de trabalho E não ocupada (desocupada), caso contrário 0. Variável de desfecho.",
                     "Rendimento mensal habitual de todos os trabalhos (valor nominal em R$)",
                     "Deflator do rendimento habitual (IBGE, base trimestral)",
                     "Rendimento mensal habitual real de todos os trabalhos (VD4019 × Habitual, em R$)",
                     "Horas habitualmente trabalhadas por semana em todos os trabalhos",
                     "Horas efetivamente trabalhadas na semana de referência em todos os trabalhos",
                     "Local de trabalho (1=estabelecimento de outro negócio/empresa, 2=local designado pelo empregador/cliente/freguês, 3=domicílio de empregador/patrão/sócio/freguês, 4=domicílio de residência em local exclusivo para a atividade, 5=domicílio de residência sem local exclusivo, 6=veículo automotor, 7=via ou área pública, 8=outro local). home_office = V4022 ∈ {4,5}. Disponível a partir de 2018T1.",
                     "Indicador de trabalho em home office (=1 se V4022 ∈ {4,5})",
                     "Código de atividade econômica do trabalho principal (CNAE-Domiciliar, 5 dígitos)",
                     "Código de ocupação do trabalho principal (COD/CBO, 4 dígitos)",
                     "Setor econômico (CNAE 2 dígitos, derivado pelo datazoom.social)",
                     "Grupo ocupacional (COD 2 dígitos, derivado pelo datazoom.social)",
                     "Motivo de afastamento do trabalho na semana de referência (2=licença maternidade/paternidade). Disponível a partir de 2015T4.",
                     "Indicador de licença-maternidade (=1 se V4006A==2)",
                     "Indicador de chefe ou cônjuge do domicílio (=1 se V2005 ∈ {1,2,3})",
                     "=1 se is_head_or_spouse==1 e há criança ≤4 anos no domicílio. Inclui filhos(as) do responsável e/ou cônjuge (V2005=4,5), enteados(as) (V2005=6) e netos(as)/bisnetos(as) (V2005=10,11). Variável de tratamento principal no DiD.",
                     "=1 se is_head_or_spouse==1 e há criança ≤4 anos no domicílio, excluindo netos(as)/bisnetos(as) (V2005=10,11). Inclui filhos(as) e enteados(as). Versão de robustez.",
                     "=1 se is_head_or_spouse==1 e há criança ≤4 anos no domicílio, excluindo enteados(as) (V2005=6). Inclui filhos(as) biológicos/adotivos (V2005=4,5) e netos(as)/bisnetos(as) (V2005=10,11). Versão de robustez.",
                     "=1 se is_head_or_spouse==1 e há criança de 5 a 7 anos no domicílio (inclui enteados e netos/bisnetos). Grupo de controle A no donut DiD.",
                     "=1 se is_head_or_spouse==1 e há criança de 5 a 7 anos no domicílio, excluindo netos(as)/bisnetos(as). Versão de robustez do Controle A.",
                     "=1 se is_head_or_spouse==1 e há criança de 5 a 7 anos no domicílio, excluindo enteados(as). Versão de robustez do Controle A.",
                     "Idade da criança mais nova ≤4 anos no domicílio (NA se has_child_u4==0)",
                     "Idade da criança mais nova ≤4 anos no domicílio, excluindo netos/bisnetos (NA se has_child_u4_no_gc==0)",
                     "Idade da criança mais nova ≤4 anos no domicílio, excluindo enteados (NA se has_child_u4_no_sc==0)",
                     "=1 se o código de ocupação (V4010/COD) é elegível para trabalho remoto (Góes et al. 2020 / Costa et al. 2024, Tabela 2)",
                     "Indicador de tratamento no DiD (= has_child_u4)",
                     "=1 se year_quarter ≥ 20222 (especificação principal: pós-MP a partir do 2º tri 2022)",
                     "=1 se year_quarter ≥ 20221 (robustez: pós-MP a partir do 1º tri 2022)",
                     "Interação DiD principal (= treated × post_mp)",
                     "Interação DiD de robustez (= treated × post_mp_alt)",
                     "=1 se VD4009==1 (empregado no setor privado com carteira = empregado CLT). Grupo em que o Art. 75-F de fato vincula. Usado como corte de placebo/heterogeneidade (não como restrição amostral). =0 para os demais, inclusive não ocupadas."
                   ),
                   
                   description_en = c(
                     "Advanced individual panel identifier (Stage 3), generated by datazoom.social via load_pnadc(panel = \"advanced_3\"). Links the same person across quarters using donated birth dates, household order number, and fuzzy matching via Graph Theory for fragmented interviews. NA when the individual could not be matched across quarters.",
                     "Household identifier, made globally unique as the composite string \"<V1014>_<id>\" (derived from datazoom's id_dom, which is unique only WITHIN each V1014 rotation group). Clustering variable in the main specifications. See the build fix note in CLAUDE.md.",
                     "Panel identifier for use in fixed effects (feols(... | id_panel)). Equal to id_rs3 when matching succeeded (panel_matched==1); when id_rs3 is NA, assigned a unique row-level ID (prefix 'unmatched_'), so different unmatched individuals are not lumped into the same spurious fixed effect.",
                     "= 1 if id_rs3 is not NA, i.e. the individual was successfully linked across quarters by the Stage 3 (Graph Theory) matching algorithm. = 0 otherwise (id_panel is a unique row-level ID).",
                     "Survey year",
                     "Survey quarter (1=Jan-Mar, 2=Apr-Jun, 3=Jul-Sep, 4=Oct-Dec)",
                     "Numeric time identifier (Year × 10 + Quarter). E.g. 20221 = Q1 2022",
                     "Interview round within the rotating panel (1 to 5 consecutive interviews per household)",
                     "State code — numeric IBGE code",
                     "Primary sampling unit (census tract or grouping)",
                     "Household selection number within PSU",
                     "Panel rotation group (panels 6 to 13 in the available data)",
                     "Post-stratification survey weight (calibrated weight)",
                     "Variance estimation stratum",
                     "Sex (1=male, 2=female)",
                     "Age in completed years",
                     "Race/color (1=white, 2=black, 3=Asian, 4=mixed/pardo, 5=indigenous)",
                     "Position in household. PNADC codes: 01=household head, 02=spouse/partner (different sex), 03=spouse/partner (same sex), 04=child of BOTH head and spouse/partner, 05=child of head ONLY, 06=stepchild, 07=son/daughter-in-law, 08=parent/stepparent of head, 09=parent-in-law, 10=grandchild, 11=great-grandchild, 12=sibling, 13=grandparent, 14=other relative, 15=non-relative member (does not share expenses), 16=non-relative member (shares expenses), 17=lodger, 18=domestic worker, 19=domestic worker's relative. NOTE: grandchild (10) and great-grandchild (11) are SEPARATE codes, not combined.",
                     "Urban/rural classification (1=urban, 2=rural)",
                     "Age group, derived from V2009 (age in years) by datazoom.social. Categories: 'Entre 14 e 17 anos' (14-17), 'Entre 18 e 24 anos' (18-24), 'Entre 25 e 29 anos' (25-29), 'Entre 30 e 39 anos' (30-39), 'Entre 40 e 49 anos' (40-49), 'Entre 50 e 59 anos' (50-59), '60 anos ou mais' (60+). Labels are in Portuguese in the raw data (package does not provide an English version).",
                     "Geographic region (Norte/North, Nordeste/Northeast, Sudeste/Southeast, Sul/South, Centro-Oeste/Center-West)",
                     "State abbreviation (2-letter, e.g. SP, RJ, MG)",
                     "Highest level of education attended or completed (1–7 scale)",
                     "Years of schooling",
                     "Education level group, derived from VD3004 (highest education level) by datazoom.social. Categories: VD3004=1 → 'Sem instrução' (no schooling); VD3004=2 → '1 a 7 anos de estudo' (1-7 years of schooling); VD3004=3 → '8 a 11 anos de estudo' (8-11 years); VD3004∈{4,5,6} → '9 a 14 anos de estudo' (9-14 years); VD3004=7 → '15 ou mais anos de estudo' (15+ years). Labels are in Portuguese in the raw data.",
                     "Labor force status in reference week (1=in labor force, 2=not in labor force)",
                     "Employment status (1=employed, 2=unemployed)",
                     "Position in main job (1=private employee with signed card, 2=private employee without signed card, 3=domestic worker with signed card, 4=domestic worker without signed card, 5=public employee with signed card, 6=public employee without signed card, 7=military/statutory servant, 8=employer, 9=self-employed, 10=unpaid family worker). clt_private = (VD4009==1).",
                     "Employed indicator (=1 if VD4002==1)",
                     "Labor force participation indicator (=1 if VD4001==1)",
                     "Formal employment. =1 includes: employees with a signed card (private, domestic, public), military/statutory servants, AND self-employed (conta própria, VD4009=9) who contribute to social security (INSS). Employers (VD4009=8) are classified as neither formal nor informal (formal=0 and informal=0), so formal+informal != 1.",
                     "Informal employment (employee without a signed card, domestic/public without a card, self-employed not contributing to INSS, unpaid family worker). Employers are not included here.",
                     "Labor force participation indicator (= forca_trab) as a clean 0/1 integer over all sample women. Outcome variable.",
                     "Employment indicator over the FULL sample: =1 if in the labor force AND occupied, else 0 (out-of-labor-force → 0). Use this, not `ocupado`, for the employment outcome and unconditional employment rates.",
                     "Unemployment indicator over the FULL sample: =1 if in the labor force AND not occupied (desocupado), else 0. Outcome variable.",
                     "Habitual monthly earnings from all jobs (nominal R$)",
                     "Habitual income deflator (IBGE, quarterly base)",
                     "Real habitual monthly earnings from all jobs (VD4019 × Habitual, in R$)",
                     "Usual weekly hours worked across all jobs",
                     "Effective hours worked in the reference week across all jobs",
                     "Work location (1=another business/firm's premises, 2=location designated by employer/client, 3=home of employer/partner/client, 4=own residence with a dedicated workspace, 5=own residence without a dedicated workspace, 6=motor vehicle, 7=public way/area, 8=other). home_office = V4022 ∈ {4,5}. Available from Q1 2018.",
                     "Home office / telework indicator (=1 if V4022 ∈ {4,5})",
                     "Economic activity code of main job (CNAE-Domiciliar, 5 digits)",
                     "Occupation code of main job (COD/CBO, 4 digits)",
                     "Economic sector (2-digit CNAE group, derived by datazoom.social)",
                     "Occupation group (2-digit COD group, derived by datazoom.social)",
                     "Reason for absence from work in reference week (2=maternity/paternity leave). Available from Q4 2015.",
                     "Maternity leave indicator (=1 if V4006A==2)",
                     "Head or spouse/partner of household (=1 if V2005 ∈ {1,2,3})",
                     "=1 if is_head_or_spouse==1 and household has a child aged ≤4. Includes biological children of head+spouse (V2005=4), children of head only (V2005=5), stepchildren (V2005=6), and grandchildren/great-grandchildren (V2005=10,11 — separate PNADC codes). Main DiD treatment indicator.",
                     "=1 if is_head_or_spouse==1 and household has a child aged ≤4, excluding grandchildren/great-grandchildren (V2005 ∈ {10,11}). Includes biological children and stepchildren. Robustness version.",
                     "=1 if is_head_or_spouse==1 and household has a child aged ≤4, excluding stepchildren (V2005=6). Includes biological children (V2005=4,5) and grandchildren/great-grandchildren (V2005 ∈ {10,11}). Robustness version.",
                     "=1 if is_head_or_spouse==1 and household has a child aged 5–7 (includes stepchildren and grandchildren/great-grandchildren). Control group A for donut DiD.",
                     "=1 if is_head_or_spouse==1 and household has a child aged 5–7, excluding grandchildren/great-grandchildren. Robustness version of Control A.",
                     "=1 if is_head_or_spouse==1 and household has a child aged 5–7, excluding stepchildren. Robustness version of Control A.",
                     "Age of youngest child aged ≤4 in the household (NA if has_child_u4==0)",
                     "Age of youngest child aged ≤4, excluding grandchildren/great-grandchildren (NA if has_child_u4_no_gc==0)",
                     "Age of youngest child aged ≤4, excluding stepchildren (NA if has_child_u4_no_sc==0)",
                     "=1 if occupation code V4010 (COD) is in the telework-eligible list (Góes et al. 2020 / Costa et al. 2024, Table 2). Used as heterogeneity moderator.",
                     "DiD treatment indicator (= has_child_u4)",
                     "=1 if year_quarter ≥ 20222 (main spec: post-MP from Q2 2022 onwards)",
                     "=1 if year_quarter ≥ 20221 (robustness: post-MP from Q1 2022 onwards)",
                     "Main DiD interaction term (= treated × post_mp)",
                     "Robustness DiD interaction term (= treated × post_mp_alt)",
                     "=1 if VD4009==1 (private-sector employee with a signed card = CLT employee). The group Art. 75-F actually binds on. Used as a placebo/heterogeneity split (not a sample restriction). =0 otherwise, including the non-employed."
                   ),
                   
                   values_notes = c(
                     "Alphanumeric string (datazoom.social Stage 3 ID format) or NA if panel linkage failed. Each individual appears in up to 5 consecutive quarters.",
                     "Character composite \"<V1014>_<id>\", globally unique across panels. E.g. '10_1'.",
                     "String. Equals id_rs3 for matched rows; 'unmatched_<row number>' for unmatched rows. Always non-missing — safe to use directly as the FE variable in feols().",
                     "0 or 1 (integer).",
                     "2018–2025",
                     "1, 2, 3, 4",
                     "E.g. 20181 (Q1 2018) through 20254 (Q4 2025)",
                     "1–5. Same individual appears in up to 5 consecutive quarters.",
                     "11=RO, 12=AC, 13=AM, 14=RR, 15=PA, 16=AP, 17=TO, 21=MA, 22=PI, 23=CE, 24=RN, 25=PB, 26=PE, 27=AL, 28=SE, 29=BA, 31=MG, 32=ES, 33=RJ, 35=SP, 41=PR, 42=SC, 43=RS, 50=MS, 51=MT, 52=GO, 53=DF",
                     "Unique code per census cluster",
                     "1–9 (selection number within PSU)",
                     "6–13 in this dataset (2018–2025)",
                     "Positive real number. Use for weighted means and totals.",
                     "Integer. Use alongside V1028 in survey-design variance estimation.",
                     "1 or 2. Sample restricted to women: V2007==2.",
                     "0–120+ (integer). Sample restricted to 18–49.",
                     "1–5. NA coded as missing in analysis.",
                     "1–13. Key values for this project: 1 (head), 2–3 (spouse), 4–6 (child), 10 (grandchild).",
                     "1 or 2",
                     "Character, one of 7 values: 'Entre 14 e 17 anos', 'Entre 18 e 24 anos', 'Entre 25 e 29 anos', 'Entre 30 e 39 anos', 'Entre 40 e 49 anos', 'Entre 50 e 59 anos', '60 anos ou mais'. Sample restriction (18-49) means only the middle 5 categories appear in practice ('Entre 14 e 17 anos' and '60 anos ou mais' will not occur).",
                     "Norte, Nordeste, Sudeste, Sul, Centro-Oeste",
                     "Two-letter string (e.g. SP, RJ, MG, BA)",
                     "1=No schooling, 2=Incomplete primary (4-year), 3=Complete primary (4-year) or incomplete (8-year), 4=Complete primary (8-year) or incomplete secondary, 5=Complete secondary or incomplete higher, 6=Complete higher, 7=Postgraduate",
                     "0–17+. Integer.",
                     "Character, one of 5 values: 'Sem instrução', '1 a 7 anos de estudo', '8 a 11 anos de estudo', '9 a 14 anos de estudo', '15 ou mais anos de estudo'. NA if VD3004 is missing.",
                     "1 or 2",
                     "1 or 2",
                     "1–10. See description for category labels.",
                     "0 or 1 (integer)",
                     "0 or 1 (integer)",
                     "0 or 1 (integer)",
                     "0 or 1 (integer)",
                     "0 or 1 (integer). = forca_trab; never NA over the sample.",
                     "0 or 1 (integer) over all sample women. Out-of-labor-force coded 0. Preferred employment outcome (`ocupado` is NA out of the labor force).",
                     "0 or 1 (integer) over all sample women. In labor force and not occupied (desocupada).",
                     "Positive real or NA (if not employed or not in scope)",
                     "Real number between 0 and 1. Multiply by VD4019 to get real income.",
                     "Positive real or NA. Main income variable for analysis.",
                     "Positive real or NA (if not employed or not in scope)",
                     "Positive real or NA",
                     "1–6. NA before Q1 2018. Key values: 4 and 5 = telework/home office.",
                     "0 or 1 (integer). NA before Q1 2018 (V4022 not collected).",
                     "5-digit integer (CNAE-Domiciliar code). NA if not employed.",
                     "4-digit integer (COD/CBO code). NA if not employed.",
                     "2-character string (e.g. '47', '85'). NA if not employed.",
                     "2-character string (e.g. '21', '41'). NA if not employed.",
                     "1–7 or NA. Available from Q4 2015. 2=maternity/paternity leave.",
                     "0 or 1 (integer). NA before Q4 2015.",
                     "0 or 1 (integer)",
                     "0 or 1 (integer). Main treatment variable in DiD specifications. V2005 ∈ {4,5,6,10,11}, age ≤4.",
                     "0 or 1 (integer). Robustness: V2005 ∈ {4,5,6}, age ≤4. Excludes grandchildren/great-grandchildren.",
                     "0 or 1 (integer). Robustness: V2005 ∈ {4,5,10,11}, age ≤4. Excludes stepchildren.",
                     "0 or 1 (integer). Control group A for donut DiD. V2005 ∈ {4,5,6,10,11}, age 5–7.",
                     "0 or 1 (integer). Robustness Control A: V2005 ∈ {4,5,6}, age 5–7. Excludes grandchildren/great-grandchildren.",
                     "0 or 1 (integer). Robustness Control A: V2005 ∈ {4,5,10,11}, age 5–7. Excludes stepchildren.",
                     "0–4 (integer) or NA",
                     "0–4 (integer) or NA",
                     "0–4 (integer) or NA",
                     "0 or 1 (integer). NA if V4010 missing (not employed). See build/01_pnadc.R for full COD code list.",
                     "0 or 1 (integer). Alias for has_child_u4.",
                     "0 or 1 (integer). Main cutoff: Q2 2022 (year_quarter ≥ 20222).",
                     "0 or 1 (integer). Alternative cutoff: Q1 2022 (year_quarter ≥ 20221). Use in robustness tables.",
                     "0 or 1 (integer). Main DiD regressor.",
                     "0 or 1 (integer). Use in robustness specifications alongside post_mp_alt.",
                     "0 or 1 (integer). Sharp CLT (private carteira) indicator, VD4009==1. Heterogeneity/placebo moderator; ~19.5% of sample women, ~34% of employed."
                   )
)

# ---- Build workbook ---------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Variables")

# Header style
header_style <- createStyle(
  fontSize    = 11,
  fontColour  = "#FFFFFF",
  fgFill      = "#1F3864",
  halign      = "CENTER",
  valign      = "CENTER",
  textDecoration = "bold",
  wrapText    = TRUE,
  border      = "Bottom",
  borderColour = "#FFFFFF"
)

# Category separator style
cat_style <- createStyle(
  fontSize    = 10,
  fontColour  = "#FFFFFF",
  fgFill      = "#2E75B6",
  textDecoration = "bold",
  wrapText    = FALSE
)

# Body style — default
body_style <- createStyle(
  fontSize  = 10,
  valign    = "TOP",
  wrapText  = TRUE,
  border    = "TopBottomLeftRight",
  borderColour = "#D9D9D9"
)

# Alternate row shade
alt_style <- createStyle(
  fgFill    = "#F2F7FD",
  fontSize  = 10,
  valign    = "TOP",
  wrapText  = TRUE,
  border    = "TopBottomLeftRight",
  borderColour = "#D9D9D9"
)

# Source color styles
src_pnadc    <- createStyle(fgFill = "#EBF3E8", fontSize = 10, valign = "TOP", wrapText = TRUE, border = "TopBottomLeftRight", borderColour = "#D9D9D9")
src_datazoom <- createStyle(fgFill = "#FFF2CC", fontSize = 10, valign = "TOP", wrapText = TRUE, border = "TopBottomLeftRight", borderColour = "#D9D9D9")
src_project  <- createStyle(fgFill = "#FCE4D6", fontSize = 10, valign = "TOP", wrapText = TRUE, border = "TopBottomLeftRight", borderColour = "#D9D9D9")

# Write header
writeData(wb, "Variables",
          x = data.frame(
            "Variable Name"     = "variable_name",
            "Source"            = "source",
            "Type"              = "type",
            "Description (PT)"  = "description_pt",
            "Description (EN)"  = "description_en",
            "Values / Notes"    = "values_notes",
            check.names = FALSE
          ),
          startRow = 1, colNames = TRUE
)
addStyle(wb, "Variables", header_style, rows = 1, cols = 1:6, gridExpand = TRUE)

# Write data rows with alternating / source-colored styles
for (i in seq_len(nrow(dict))) {
  r <- i + 1  # row 1 is header
  writeData(wb, "Variables",
            x       = dict[i, c("variable_name","source","type",
                                "description_pt","description_en","values_notes")],
            startRow = r, colNames = FALSE
  )
  sty <- switch(dict$source[i],
                "PNADC raw"          = src_pnadc,
                "datazoom.social"    = src_datazoom,
                "Project-derived"    = src_project,
                if (i %% 2 == 0) alt_style else body_style
  )
  addStyle(wb, "Variables", sty, rows = r, cols = 1:6, gridExpand = TRUE)
}

# Column widths
setColWidths(wb, "Variables", cols = 1, widths = 28)
setColWidths(wb, "Variables", cols = 2, widths = 18)
setColWidths(wb, "Variables", cols = 3, widths = 12)
setColWidths(wb, "Variables", cols = 4, widths = 50)
setColWidths(wb, "Variables", cols = 5, widths = 50)
setColWidths(wb, "Variables", cols = 6, widths = 55)

# Freeze header row
freezePane(wb, "Variables", firstRow = TRUE)

# ---- Legend sheet -----------------------------------------------------------
addWorksheet(wb, "Legend")
legend_df <- data.frame(
  Source = c("PNADC raw", "datazoom.social", "Project-derived"),
  Color  = c("Green", "Yellow", "Orange"),
  Description = c(
    "Variable comes directly from the PNADC microdata questionnaire.",
    "Variable derived by the datazoom.social R package (PUC-Rio). See: github.com/datazoompuc/datazoom.social",
    "Variable created in build/01_pnadc.R for this research project (treatment indicators, child flags, panel ID for FE, etc.)."
  )
)
writeData(wb, "Legend", legend_df, startRow = 1)
addStyle(wb, "Legend", header_style, rows = 1, cols = 1:3)
addStyle(wb, "Legend", src_pnadc,    rows = 2, cols = 1:3, gridExpand = TRUE)
addStyle(wb, "Legend", src_datazoom, rows = 3, cols = 1:3, gridExpand = TRUE)
addStyle(wb, "Legend", src_project,  rows = 4, cols = 1:3, gridExpand = TRUE)
setColWidths(wb, "Legend", cols = 1:3, widths = c(20, 12, 70))

# ---- Save -------------------------------------------------------------------
out_path <- here("dictionary", "variable_dictionary.xlsx")
saveWorkbook(wb, out_path, overwrite = TRUE)
message("Dictionary saved: ", out_path)