PGDMP     	                    t            irci_    9.6.1    9.6.1 ,    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                       false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                       false            	            2615    16385    irci    SCHEMA        CREATE SCHEMA irci;
    DROP SCHEMA irci;
             postgres    false            �            1255    16447    get_konfig_lang_model(uuid)    FUNCTION     -  CREATE FUNCTION get_konfig_lang_model(p_id_konfig uuid) RETURNS TABLE(id_konfig uuid, kd_konfig text, entity text, path text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY
	WITH data_konfig AS (
		SELECT t1.id_konfig, t1.kd_konfig
			, regexp_split_to_array(t1.konfig, E'##+') as konfig
		FROM irci.konfig t1
		WHERE t1.id_konfig = p_id_konfig
		)
	SELECT t1.id_konfig, t1.kd_konfig
		, (regexp_split_to_array(t1.konfig[1], E'::+'))[2] as entity
		, (regexp_split_to_array(t1.konfig[2], E'::+'))[2] as path
	FROM data_konfig t1;
END;
$$;
 <   DROP FUNCTION irci.get_konfig_lang_model(p_id_konfig uuid);
       irci       postgres    false    9            �            1255    16448    get_str_similarity(text, text)    FUNCTION     �  CREATE FUNCTION get_str_similarity(p_string_1 text, p_string_2 text) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE v_sim numeric := 0;
BEGIN
	WITH the_data AS (
	SELECT t1.term_1, t2.term_2
		, array_length(term_1, 1) as len_term_1
		, array_length(term_2, 1) as len_term_2
	FROM ( SELECT show_trgm(regexp_replace(p_string_1, '[^a-zA-Z ]+', '', 'g')) as term_1 ) t1
	CROSS JOIN (
		SELECT show_trgm(regexp_replace(p_string_2, '[^a-zA-Z ]+', '', 'g')) as term_2
		) t2
	)
	
	SELECT 	CASE WHEN len_term_1 < len_term_2 THEN n_match/len_term_1
		     ELSE n_match/len_term_2
		END as similarity INTO v_sim
	FROM the_data t1
	CROSS JOIN (
		SELECT count(*)::numeric as n_match
		FROM ( 	SELECT unnest(term_1) as term
			FROM the_data ) t1
		INNER JOIN ( 	SELECT unnest(term_2) as term
			FROM the_data ) t2 
			ON t1.term = t2.term
		) t2;

	RETURN v_sim;

END;
$$;
 I   DROP FUNCTION irci.get_str_similarity(p_string_1 text, p_string_2 text);
       irci       postgres    false    9            �            1255    16449 <   insert_ekstraksi_referensi_raw(uuid, uuid, text, text, text)    FUNCTION     �  CREATE FUNCTION insert_ekstraksi_referensi_raw(p_id_identifier uuid, p_id_referensi_raw uuid, p_authors text, p_title text, p_year text) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN	
--	DELETE FROM irci.metadata_referensi_raw
--	WHERE id_identifier = p_id_identifier;
	
	INSERT INTO irci.metadata_referensi_raw(id_referensi_raw, id_identifier, authors, title, theyear)
	VALUES (p_id_referensi_raw, p_id_identifier, p_authors, p_title, p_year);

	UPDATE irci.referensi_raw
	SET tgl_updated = now()
		, status = '1'
	WHERE irci.referensi_raw.id_identifier = p_id_identifier;

	v_ret := '1';

	RETURN v_ret;
END;
$$;
 �   DROP FUNCTION irci.insert_ekstraksi_referensi_raw(p_id_identifier uuid, p_id_referensi_raw uuid, p_authors text, p_title text, p_year text);
       irci       postgres    false    9            �            1255    16450 $   insert_referensi_raw(uuid[], text[])    FUNCTION     �  CREATE FUNCTION insert_referensi_raw(p_id_identifier uuid[], p_referensi_raw text[]) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN	
	DELETE FROM irci.referensi_raw
	WHERE id_identifier IN (
		SELECT distinct unnest(p_id_identifier)
		);
	
	INSERT INTO irci.referensi_raw(id_identifier, referensi_raw)
	SELECT t1.*
	FROM (SELECT unnest(p_id_identifier) as id_identifier,
		unnest(p_referensi_raw) as referensi_raw
		) t1;

	UPDATE irci.harvesting_info
	SET tgl_retrieve_referensi_raw = now()
		, jml_referensi_raw = t1.jml_referensi_raw
		, tgl_updated = now()
	FROM (	SELECT tb.id_identify
			, count(ta.id_identifier) as jml_referensi_raw
		FROM irci.referensi_raw ta
		INNER JOIN irci.identifier tb ON ta.id_identifier = tb.id_identifier
			AND tb.id_identifier IN (
				SELECT distinct unnest(p_id_identifier)
				)
		GROUP BY tb.id_identify
		) t1
	WHERE irci.harvesting_info.id_identify = t1.id_identify;

	v_ret := '1';

	RETURN v_ret;
END;
$$;
 Y   DROP FUNCTION irci.insert_referensi_raw(p_id_identifier uuid[], p_referensi_raw text[]);
       irci       postgres    false    9            �            1255    16451 U   insup_indentifier(uuid[], text[], timestamp without time zone[], text[], character[])    FUNCTION       CREATE FUNCTION insup_indentifier(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_status character[]) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN
	UPDATE irci.identifier
	SET datestamp = t1.datestamp,
		set_spec = t1.set_spec,
		status = t1.status,
		tgl_updated = now()
	FROM (SELECT DISTINCT unnest(p_id_identify) as id_identify, 
		unnest(p_oai_identifier) as oai_identifier, 
		unnest(p_datestamp) as datestamp, 
		unnest(p_set_spec) as set_spec, 
		unnest(p_status) as status
		) t1		
	WHERE irci.identifier.oai_identifier = t1.oai_identifier
		AND irci.identifier.datestamp != t1.datestamp;

	DELETE FROM irci.records 
	WHERE oai_identifier IN (
		SELECT ta.oai_identifier FROM irci.identifier ta
		WHERE ta.status = '0');

	INSERT INTO irci.identifier(id_identify, oai_identifier, datestamp, set_spec, status)
	SELECT t1.*
	FROM (SELECT DISTINCT unnest(p_id_identify) as id_identify, 
		unnest(p_oai_identifier) as oai_identifier, 
		unnest(p_datestamp) as datestamp, 
		unnest(p_set_spec) as set_spec, 
		unnest(p_status) as status
		) t1
	WHERE NOT t1.oai_identifier IN (
		SELECT ta.oai_identifier FROM irci.identifier ta);

	UPDATE irci.harvesting_info
	SET tgl_retrieve_identify = now()
		, last_datestamp_identifier = t1.last_datestamp
		, jml_identifier = t1.jml_identifier
		, tgl_updated = now()
	FROM (	SELECT ta.id_identify, max(ta.datestamp) as last_datestamp
			, count(ta.id_identifier) as jml_identifier
		FROM irci.identifier ta
		WHERE ta.id_identify IN (
			SELECT distinct unnest(p_id_identify))
		GROUP BY ta.id_identify
		) t1
	WHERE irci.harvesting_info.id_identify = t1.id_identify;

	v_ret := '1';

	RETURN v_ret;
END;
$$;
 �   DROP FUNCTION irci.insup_indentifier(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_status character[]);
       irci       postgres    false    9            �            1255    16452 s   insup_indentify(text, text, text, timestamp without time zone, text, text, text, text, text, text, uuid, character)    FUNCTION     }  CREATE FUNCTION insup_indentify(p_base_url text, p_repo_name text DEFAULT NULL::text, p_protocol_ver text DEFAULT NULL::text, p_earliest_datestamp timestamp without time zone DEFAULT NULL::timestamp without time zone, p_granularity text DEFAULT NULL::text, p_admin_email text DEFAULT NULL::text, p_schema_name text DEFAULT NULL::text, p_repo_identifier text DEFAULT NULL::text, p_delimiter_char text DEFAULT NULL::text, p_sample_oai_identifier text DEFAULT NULL::text, p_id_identify uuid DEFAULT NULL::uuid, p_kd_sts_aktif character DEFAULT '1'::character(1)) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN
	
	IF (p_id_identify is NULL) THEN		
		INSERT INTO irci.identify(base_url)
		VALUES (p_base_url);

		INSERT INTO irci.harvesting_info(id_identify)
		SELECT ta.id_identify FROM irci.identify ta
		WHERE ta.base_url = p_base_url;

		v_ret := '1';
	ELSE
		UPDATE irci.identify
		SET repo_name = p_repo_name
			, base_url = p_base_url
			, protocol_ver = p_protocol_ver
			, earliest_datestamp = p_earliest_datestamp
			, granularity = p_granularity
			, admin_email = p_admin_email
			, schema_name = p_schema_name
			, repo_identifier = p_repo_identifier
			, delimiter_char = p_delimiter_char
			, sample_oai_identifier = p_sample_oai_identifier
			, kd_sts_aktif = p_kd_sts_aktif
			, tgl_updated = now()
		WHERE id_identify = p_id_identify;

		IF EXISTS (
			SELECT ta.id_harvesting_info FROM irci.harvesting_info ta
			WHERE ta.id_identify = p_id_identify) THEN

			UPDATE irci.harvesting_info
			SET tgl_retrieve_identify = now()
				, tgl_updated = now()
			WHERE id_identify = p_id_identify;
		ELSE
			INSERT INTO irci.harvesting_info(
				id_identify, tgl_registrasi, tgl_retrieve_identify)
			SELECT p_id_identify, ta.tgl_created, now()
			FROM irci.identify ta WHERE ta.id_identify = p_id_identify;
		END IF;

		v_ret := '1';
	END IF;

	RETURN v_ret;
END;
$$;
 E  DROP FUNCTION irci.insup_indentify(p_base_url text, p_repo_name text, p_protocol_ver text, p_earliest_datestamp timestamp without time zone, p_granularity text, p_admin_email text, p_schema_name text, p_repo_identifier text, p_delimiter_char text, p_sample_oai_identifier text, p_id_identify uuid, p_kd_sts_aktif character);
       irci       postgres    false    9            �            1255    16453 4   insup_konfig(character, text, text, uuid, character)    FUNCTION     �  CREATE FUNCTION insup_konfig(p_kd_kelompok_konfig character, p_kd_konfig text, p_konfig text, p_id_konfig uuid DEFAULT NULL::uuid, p_kd_sts_aktif character DEFAULT '1'::character(1)) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN	
	IF (p_id_konfig is NULL) THEN		
		INSERT INTO irci.konfig(kd_kelompok_konfig, kd_konfig, konfig)
		VALUES (p_kd_kelompok_konfig, p_kd_konfig, p_konfig);

		v_ret := '1';
	ELSE
		UPDATE irci.konfig
		SET kd_kelompok_konfig = p_kd_kelompok_konfig
			, kd_konfig = p_kd_konfig
			, konfig = p_konfig
			, tgl_updated = now()
		WHERE id_identify = p_id_identify;

		v_ret := '1';
	END IF;

	RETURN v_ret;
END;
$$;
 �   DROP FUNCTION irci.insup_konfig(p_kd_kelompok_konfig character, p_kd_konfig text, p_konfig text, p_id_konfig uuid, p_kd_sts_aktif character);
       irci       postgres    false    9            �            1255    16454 ,   insup_metadata(uuid, text, text, text, uuid)    FUNCTION     �  CREATE FUNCTION insup_metadata(p_id_identify uuid, p_metadata_prefix text DEFAULT NULL::text, p_metadata_namespace text DEFAULT NULL::text, p_metadata_schema text DEFAULT NULL::text, p_id_metadata_format uuid DEFAULT NULL::uuid) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN
	
	IF (p_id_metadata_format is NULL) THEN				
		INSERT INTO irci.metadata_formats(id_identify, metadata_prefix, metadata_namespace, metadata_schema)
		VALUES (p_id_identify, p_metadata_prefix, p_metadata_namespace, p_metadata_schema);

		v_ret := '1';
	ELSE
		UPDATE irci.metadata_formats
		SET id_identify = p_id_identify
			, metadata_prefix = p_metadata_prefix
			, metadata_namespace = p_metadata_namespace
			, metadata_schema = p_metadata_schema
			, tgl_updated = now()
		WHERE id_metadata_format = p_id_metadata_format;

		v_ret := '1';
	END IF;

	RETURN v_ret;
END;
$$;
 �   DROP FUNCTION irci.insup_metadata(p_id_identify uuid, p_metadata_prefix text, p_metadata_namespace text, p_metadata_schema text, p_id_metadata_format uuid);
       irci       postgres    false    9            �            1255    16455 �   insup_record(uuid[], text[], timestamp without time zone[], text[], text[], text[], text[], text[], text[], text[], timestamp without time zone[], text[], text[], text[], text[], text[], text[], text[])    FUNCTION     �  CREATE FUNCTION insup_record(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_title text[], p_subject_keywords text[], p_description text[], p_publisher text[], p_author_creator text[], p_contibutor text[], p_date_submission timestamp without time zone[], p_resource_type text[], p_format text[], p_resource_identifier text[], p_source text[], p_bahasa text[], p_relation text[], p_right_management text[]) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN

	UPDATE irci.records
	SET datestamp = t1.datestamp,
		set_spec = t1.set_spec,
		title = t1.title,
		subject_keywords = t1.subject_keywords,
		description = t1.description,
		publisher = t1.publisher,
		author_creator = t1.author_creator,
		contributor = t1.contributor,
		date_submission = t1.date_submission,
		resource_type = t1.resource_type,
		format = t1.format,
		resource_identifier = t1.resource_identifier,
		source = t1.source,
		bahasa = t1.bahasa,
		relation = t1.relation,
		right_management = t1.right_management,
		tgl_updated = now()
	FROM (	SELECT t1.*
		FROM (	SELECT DISTINCT unnest(p_oai_identifier) as oai_identifier, 
			unnest(p_datestamp) as datestamp, 
			unnest(p_set_spec) as set_spec, 
			unnest(p_title) as title,
			unnest(p_subject_keywords) as subject_keywords, 
			unnest(p_description) as description, 
			unnest(p_publisher) as publisher,
			string_to_array(unnest(p_author_creator), '~#~') as author_creator, 
			string_to_array(unnest(p_contibutor), '~#~') as contributor, 
			unnest(p_date_submission)::date as date_submission, 
			string_to_array(unnest(p_resource_type), '~#~') as resource_type, 
			unnest(p_format) as format, 
			unnest(p_resource_identifier) as resource_identifier,
			string_to_array(unnest(p_source), '~#~') as source,
			unnest(p_bahasa) as bahasa,
			unnest(p_relation) as relation, 
			string_to_array(unnest(p_right_management), '~#~') as right_management
			) t1
		INNER JOIN irci.identifier t2 ON t1.oai_identifier = t2.oai_identifier
			AND t2.status = '1'
		) t1
	WHERE irci.records.oai_identifier = t1.oai_identifier
		AND irci.records.datestamp != t1.datestamp;
	

	INSERT INTO irci.records(id_identify, oai_identifier, datestamp, set_spec, title
		, subject_keywords, description, publisher, author_creator, contributor
		, date_submission, resource_type, format, resource_identifier
		, source, bahasa, relation, right_management)
	SELECT t1.*
	FROM (SELECT DISTINCT unnest(p_id_identify) as id_identify, 
		unnest(p_oai_identifier) as oai_identifier, 
		unnest(p_datestamp) as datestamp, 
		unnest(p_set_spec) as set_spec, 
		unnest(p_title) as title,
		unnest(p_subject_keywords) as subject_keywords, 
		unnest(p_description) as description, 
		unnest(p_publisher) as publisher,
		string_to_array(unnest(p_author_creator), '~#~') as author_creator, 
		string_to_array(unnest(p_contibutor), '~#~') as contributor, 
		unnest(p_date_submission) as date_submission, 
		string_to_array(unnest(p_resource_type), '~#~') as resource_type, 
		unnest(p_format) as format, 
		unnest(p_resource_identifier) as resource_identifier,
		string_to_array(unnest(p_source), '~#~') as source,
		unnest(p_bahasa) as bahasa,
		unnest(p_relation) as relation, 
		string_to_array(unnest(p_right_management), '~#~') as right_management
		) t1
	WHERE NOT t1.oai_identifier IN (
		SELECT ta.oai_identifier FROM irci.records ta);

	UPDATE irci.harvesting_info
	SET tgl_retrieve_record = now()
		, last_datestamp_record = t1.last_datestamp
		, jml_record = t1.jml_record
		, tgl_updated = now()
	FROM (	SELECT ta.id_identify, max(ta.datestamp) as last_datestamp
			, count(ta.id_record) as jml_record
		FROM irci.records ta
		WHERE ta.id_identify IN (
			SELECT distinct unnest(p_id_identify))
		GROUP BY ta.id_identify
		) t1
	WHERE irci.harvesting_info.id_identify = t1.id_identify;

	v_ret := '1';

	RETURN v_ret;
END;
$$;
 �  DROP FUNCTION irci.insup_record(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_title text[], p_subject_keywords text[], p_description text[], p_publisher text[], p_author_creator text[], p_contibutor text[], p_date_submission timestamp without time zone[], p_resource_type text[], p_format text[], p_resource_identifier text[], p_source text[], p_bahasa text[], p_relation text[], p_right_management text[]);
       irci       postgres    false    9            �            1255    16456 "   insup_sets(uuid, text, text, uuid)    FUNCTION     �  CREATE FUNCTION insup_sets(p_id_identify uuid DEFAULT NULL::uuid, p_set_name text DEFAULT NULL::text, p_set_spec text DEFAULT NULL::text, p_id_sets uuid DEFAULT NULL::uuid) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN
	
	IF (p_id_sets is NULL) THEN				
		INSERT INTO irci.sets(id_identify, set_name, set_spec)
		VALUES (p_id_identify, p_set_name, p_set_spec);

		v_ret := '1';
	ELSE
		UPDATE irci.sets
		SET id_identify = p_id_identify
			, set_name = p_set_name
			, set_spec = p_set_spec
			, tgl_updated = now()
		WHERE id_sets = p_id_sets;

		v_ret := '1';
	END IF;

	RETURN v_ret;
END;
$$;
 e   DROP FUNCTION irci.insup_sets(p_id_identify uuid, p_set_name text, p_set_spec text, p_id_sets uuid);
       irci       postgres    false    9            �            1255    16457 7   insup_toolkit(uuid, text, text, text, text, text, text)    FUNCTION     �  CREATE FUNCTION insup_toolkit(p_id_identify uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_author_name text DEFAULT NULL::text, p_author_email text DEFAULT NULL::text, p_version text DEFAULT NULL::text, p_url text DEFAULT NULL::text, p_compression text DEFAULT NULL::text) RETURNS character
    LANGUAGE plpgsql
    AS $$
DECLARE v_ret character(1) := '0';
BEGIN
	
	IF NOT EXISTS(
		SELECT ta.* FROM irci.toolkit ta
		WHERE ta.id_identify = p_id_identify) THEN
				
		INSERT INTO irci.toolkit(id_identify, title, author_name, author_email, version, url, compression)
		VALUES (p_id_identify, p_title, p_author_name, p_author_email, p_version, p_url, p_compression);

		v_ret := '1';
	ELSE
		UPDATE irci.toolkit
		SET title = p_title
			, author_name = p_author_name
			, author_email = p_author_email
			, version = p_version
			, url = p_url
			, compression = p_compression
			, tgl_updated = now()
		WHERE id_identify = p_id_identify;

		v_ret := '1';
	END IF;

	RETURN v_ret;
END;
$$;
 �   DROP FUNCTION irci.insup_toolkit(p_id_identify uuid, p_title text, p_author_name text, p_author_email text, p_version text, p_url text, p_compression text);
       irci       postgres    false    9            �            1255    16458 '   list_identifier(uuid, integer, integer)    FUNCTION     
  CREATE FUNCTION list_identifier(p_id_identify uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid, p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_identifier uuid, oai_identifier text, datestamp timestamp without time zone, set_spec text, title text, resource_identifier text, jml_referensi integer)
    LANGUAGE plpgsql
    AS $$
DECLARE v_identify uuid[];
BEGIN
	IF (p_id_identify != '00000000-0000-0000-0000-000000000000'::uuid) THEN
		 SELECT ARRAY[p_id_identify] INTO v_identify;
	ELSE
		SELECT ARRAY_AGG(t1.id_identify) INTO v_identify
		FROM irci.identify t1;
	END IF;
	
	IF p_jml_data = 0 THEN	
		RETURN QUERY
		WITH data_identifier AS (
			SELECT row_number(*) over(ORDER BY t1.datestamp DESC)::int as no_baris
				, t1.id_identifier, t1.oai_identifier
				, t1.datestamp, t1.set_spec
			FROM irci.identifier t1
			WHERE t1.id_identify IN (SELECT unnest(v_identify))
				AND t1.status != '0'
			),
		referensi_data AS (
			SELECT t1.id_identifier, COALESCE(count(id_referensi_raw),0)::integer as jml_referensi
			FROM data_identifier t1
			LEFT JOIN irci.referensi_raw t2 ON t1.id_identifier = t2.id_identifier
			GROUP BY t1.id_identifier
			)
		SELECT t1.*
			, CASE WHEN t2.title is null THEN '-'
				ELSE t2.title
			  END::text as title
			, t2.resource_identifier
			, t3.jml_referensi
		FROM data_identifier t1
		LEFT JOIN irci.records t2 ON t1.oai_identifier = t2.oai_identifier
		INNER JOIN referensi_data t3 ON t1.id_identifier = t3.id_identifier
		ORDER BY t1.no_baris ASC;
	ELSE	
		RETURN QUERY	
		WITH data_identifier AS (
			SELECT row_number(*) over(ORDER BY t1.datestamp DESC)::int as no_baris
				, t1.id_identifier, t1.oai_identifier
				, t1.datestamp, t1.set_spec
			FROM irci.identifier t1
			WHERE t1.id_identify IN ( SELECT unnest(v_identify) )	
				AND t1.status != '0'
			LIMIT p_jml_data OFFSET p_offset
			),
		referensi_data AS (
			SELECT t1.id_identifier, COALESCE(count(id_referensi_raw),0)::integer as jml_referensi
			FROM data_identifier t1
			LEFT JOIN irci.referensi_raw t2 ON t1.id_identifier = t2.id_identifier
			GROUP BY t1.id_identifier
			)			
		SELECT t1.*
			, CASE WHEN t2.title is null THEN '-'
				ELSE t2.title
			  END::text as title
			, t2.resource_identifier
			, t3.jml_referensi
		FROM data_identifier t1
		LEFT JOIN irci.records t2 ON t1.oai_identifier = t2.oai_identifier		
		INNER JOIN referensi_data t3 ON t1.id_identifier = t3.id_identifier
		ORDER BY t1.no_baris ASC;	
	END IF;	
END;
$$;
 ^   DROP FUNCTION irci.list_identifier(p_id_identify uuid, p_jml_data integer, p_offset integer);
       irci       postgres    false    9            �            1255    16459    list_jurnal(integer, integer)    FUNCTION     a  CREATE FUNCTION list_jurnal(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_identify uuid, repo_name text, base_url text, admin_email text, jml_artikel integer, last_updated text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF p_jml_data = 0 THEN	
		RETURN QUERY
		WITH data_jurnal AS (
			SELECT t1.id_identify, COALESCE(t1.repo_name, '-')::text repo_name
				, t1.base_url, COALESCE(t1.admin_email, '-')::text admin_email
			FROM irci.identify t1
			),
		jml_artikel AS (
			SELECT t1.id_identify, count(t2.id_record)::int as jml_artikel
				, max(t2.datestamp)::text as last_updated
			FROM data_jurnal t1
			INNER JOIN irci.records t2 ON t1.id_identify = t2.id_identify
			GROUP BY t1.id_identify
			)
		SELECT row_number(*) over(ORDER BY t2.last_updated DESC)::int as no_baris
			, t1.*, COALESCE(t2.jml_artikel, 0::int) as jml_artikel
			, COALESCE(t2.last_updated, '-')::text as last_updated
		FROM data_jurnal t1
		LEFT JOIN jml_artikel t2 ON t1.id_identify = t2.id_identify
		ORDER BY t2.last_updated DESC;
	ELSE	
		RETURN QUERY	
			WITH data_jurnal AS (
			SELECT t1.id_identify, COALESCE(t1.repo_name, '-')::text repo_name
				, t1.base_url, COALESCE(t1.admin_email, '-')::text admin_email
			FROM irci.identify t1
			),
		jml_artikel AS (
			SELECT t1.id_identify, count(t2.id_record)::int as jml_artikel
				, max(t2.tgl_updated)::text as last_updated
			FROM data_jurnal t1
			INNER JOIN irci.records t2 ON t1.id_identify = t2.id_identify
			GROUP BY t1.id_identify
			)
		SELECT row_number(*) over(ORDER BY t2.last_updated DESC)::int as no_baris
			, t1.*, COALESCE(t2.jml_artikel, 0::int) as jml_artikel
			, COALESCE(t2.last_updated, '-')::text as last_updated
		FROM data_jurnal t1
		LEFT JOIN jml_artikel t2 ON t1.id_identify = t2.id_identify
		ORDER BY t2.last_updated DESC
		LIMIT p_jml_data OFFSET p_offset;	
	END IF;	
END;
$$;
 F   DROP FUNCTION irci.list_jurnal(p_jml_data integer, p_offset integer);
       irci       postgres    false    9            �            1255    16460 (   list_konfig_lang_model(integer, integer)    FUNCTION     q  CREATE FUNCTION list_konfig_lang_model(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_konfig uuid, kd_konfig text, entity text, path text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF p_jml_data = 0 THEN	
		RETURN QUERY
		WITH data_konfig AS (
			SELECT t1.id_konfig, t1.kd_konfig
				, regexp_split_to_array(t1.konfig, E'##+') as konfig
			FROM irci.konfig t1
			WHERE t1.kd_sts_aktif = '1'
				AND kd_kelompok_konfig = 'A'
			)
		SELECT row_number(*) over(ORDER BY t1.kd_konfig ASC)::int as no_baris
			, t1.id_konfig, t1.kd_konfig
			, (regexp_split_to_array(t1.konfig[1], E'::+'))[2] as entity
			, (regexp_split_to_array(t1.konfig[2], E'::+'))[2] as path
		FROM data_konfig t1		
		ORDER BY t1.kd_konfig ASC;
	ELSE	
		RETURN QUERY	
		WITH data_konfig AS (
			SELECT t1.id_konfig, t1.kd_konfig
				, regexp_split_to_array(t1.konfig, E'##+') as konfig
			FROM irci.konfig t1
			WHERE t1.kd_sts_aktif = '1'
				AND kd_kelompok_konfig = 'A'
			ORDER BY t1.kd_konfig ASC
			LIMIT p_jml_data OFFSET p_offset
			)
		SELECT row_number(*) over(ORDER BY t1.kd_konfig ASC)::int as no_baris
			, t1.id_konfig, t1.kd_konfig
			, (regexp_split_to_array(t1.konfig[1], E'::+'))[2] as entity
			, (regexp_split_to_array(t1.konfig[2], E'::+'))[2] as path
		FROM data_konfig t1	
		ORDER BY t1.kd_konfig ASC;			
	END IF;	
END;
$$;
 Q   DROP FUNCTION irci.list_konfig_lang_model(p_jml_data integer, p_offset integer);
       irci       postgres    false    9            �            1255    16461 (   list_konfig_user_level(integer, integer)    FUNCTION     �  CREATE FUNCTION list_konfig_user_level(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_konfig uuid, kd_konfig text, userlevel integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF p_jml_data = 0 THEN	
		RETURN QUERY
		WITH data_konfig AS (
			SELECT t1.id_konfig, t1.kd_konfig
				, regexp_split_to_array(t1.konfig, E'##+') as konfig
			FROM irci.konfig t1
			WHERE t1.kd_sts_aktif = '1'
				AND kd_kelompok_konfig = 'B'
			)
		SELECT row_number(*) over(ORDER BY t1.kd_konfig ASC)::int as no_baris
			, t1.id_konfig, t1.kd_konfig
			, (regexp_split_to_array(t1.konfig[1], E'::+'))[2]::int as userlevel
		FROM data_konfig t1		
		ORDER BY t1.kd_konfig ASC;
	ELSE	
		RETURN QUERY	
		WITH data_konfig AS (
			SELECT t1.id_konfig, t1.kd_konfig
				, regexp_split_to_array(t1.konfig, E'##+') as konfig
			FROM irci.konfig t1
			WHERE t1.kd_sts_aktif = '1'
				AND kd_kelompok_konfig = 'B'
			ORDER BY t1.kd_konfig ASC
			LIMIT p_jml_data OFFSET p_offset
			)
		SELECT row_number(*) over(ORDER BY t1.kd_konfig ASC)::int as no_baris
			, t1.id_konfig, t1.kd_konfig
			, (regexp_split_to_array(t1.konfig[1], E'::+'))[2]::int as userlevel
		FROM data_konfig t1	
		ORDER BY t1.kd_konfig ASC;			
	END IF;	
END;
$$;
 Q   DROP FUNCTION irci.list_konfig_user_level(p_jml_data integer, p_offset integer);
       irci       postgres    false    9            �            1255    16462 $   list_referensi_raw(integer, integer)    FUNCTION     �  CREATE FUNCTION list_referensi_raw(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_referensi_raw uuid, id_identifier uuid, referensi_raw text, tgl_created timestamp without time zone, status character, title text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF p_jml_data = 0 THEN	
		RETURN QUERY
		WITH data_referensi_raw AS (
			SELECT row_number(*) over(ORDER BY t1.id_identifier, t1.tgl_created DESC)::int as no_baris
				, t1.id_referensi_raw, t1.id_identifier, t1.referensi_raw
				, t1.tgl_created, t1.status
			FROM irci.referensi_raw t1
			ORDER BY t1.id_identifier, t1.tgl_created DESC
			)
		SELECT t1.*, t3.title 
		FROM data_referensi_raw t1
		INNER JOIN irci.identifier t2 ON t1.id_identifier = t2.id_identifier
		INNER JOIN irci.records t3 ON t2.oai_identifier = t3.oai_identifier
		ORDER BY t1.no_baris ASC;
	ELSE	
		RETURN QUERY	
		WITH data_referensi_raw AS (
			SELECT row_number(*) over(ORDER BY t1.id_identifier, t1.tgl_created DESC)::int as no_baris
				, t1.id_referensi_raw, t1.id_identifier, t1.referensi_raw
				, t1.tgl_created, t1.status
			FROM irci.referensi_raw t1
			ORDER BY t1.id_identifier, t1.tgl_created DESC
			LIMIT p_jml_data OFFSET p_offset
			)
		SELECT t1.*, t3.title
		FROM data_referensi_raw t1
		INNER JOIN irci.identifier t2 ON t1.id_identifier = t2.id_identifier
		INNER JOIN irci.records t3 ON t2.oai_identifier = t3.oai_identifier
		ORDER BY t1.no_baris ASC;
	END IF;	
END;
$$;
 M   DROP FUNCTION irci.list_referensi_raw(p_jml_data integer, p_offset integer);
       irci       postgres    false    9            �            1255    16463     list_unextracted_referensi_raw()    FUNCTION       CREATE FUNCTION list_unextracted_referensi_raw() RETURNS TABLE(no_baris integer, id_referensi_raw uuid, id_identifier uuid, referensi_raw text, tgl_created timestamp without time zone, status character, title text)
    LANGUAGE plpgsql
    AS $$
DECLARE v_tgl_update timestamp without time zone:= now();
BEGIN
	--v_tgl_update := (select max(t2.tgl_created) from irci.metadata_referensi_raw as t2);
	
--	IF v_tgl_update IS NULL THEN	
		RETURN QUERY
		WITH data_referensi_raw AS (
			SELECT row_number(*) over(ORDER BY t1.id_identifier, t1.tgl_created DESC)::int as no_baris
				, t1.id_referensi_raw, t1.id_identifier, t1.referensi_raw
				, t1.tgl_created, t1.status
			FROM irci.referensi_raw t1
			WHERE t1.status='0'
			ORDER BY t1.id_identifier, t1.tgl_created DESC
			LIMIT 10 OFFSET 0
			)
		SELECT t1.*, t3.title 
		FROM data_referensi_raw t1
		INNER JOIN irci.identifier t2 ON t1.id_identifier = t2.id_identifier
		INNER JOIN irci.records t3 ON t2.oai_identifier = t3.oai_identifier
		ORDER BY t1.no_baris ASC;

END;
$$;
 5   DROP FUNCTION irci.list_unextracted_referensi_raw();
       irci       postgres    false    9            �            1255    16464 	   test_py()    FUNCTION     \  CREATE FUNCTION test_py() RETURNS TABLE(repo_name text, base_url text)
    LANGUAGE plpythonu
    AS $$
import psycopg2.extras
plan = plpy.prepare(
"SELECT t1.repo_name, t1.base_url FROM irci.identify t1 ORDER BY t1.repo_name;"
)
repo_rows = list(plpy.execute(plan))

nomor = 1
for row in repo_rows:	
	nomor += 1
	
return repo_rows
$$;
    DROP FUNCTION irci.test_py();
       irci       postgres    false    9            �            1259    21581    article    TABLE     �   CREATE TABLE article (
    id integer NOT NULL,
    title text,
    author text[],
    date_submission date,
    reference_title text,
    reference_author text,
    reference_year text,
    status character(1) DEFAULT 0 NOT NULL
);
    DROP TABLE irci.article;
       irci         postgres    false    9            �            1259    21579    article_id_seq    SEQUENCE     p   CREATE SEQUENCE article_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE irci.article_id_seq;
       irci       postgres    false    9    201            �           0    0    article_id_seq    SEQUENCE OWNED BY     3   ALTER SEQUENCE article_id_seq OWNED BY article.id;
            irci       postgres    false    200            �            1259    21643    scholar_account    TABLE     �   CREATE TABLE scholar_account (
    id integer NOT NULL,
    username character varying NOT NULL,
    password character varying DEFAULT 12345678 NOT NULL
);
 !   DROP TABLE irci.scholar_account;
       irci         postgres    false    9            �            1259    21641    scholar_account_id_seq    SEQUENCE     x   CREATE SEQUENCE scholar_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE irci.scholar_account_id_seq;
       irci       postgres    false    205    9            �           0    0    scholar_account_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE scholar_account_id_seq OWNED BY scholar_account.id;
            irci       postgres    false    204            �            1259    21592    scholar_profile    TABLE     m   CREATE TABLE scholar_profile (
    id integer NOT NULL,
    name text,
    citation_num integer DEFAULT 0
);
 !   DROP TABLE irci.scholar_profile;
       irci         postgres    false    9            �           0    0    COLUMN scholar_profile.id    COMMENT     .   COMMENT ON COLUMN scholar_profile.id IS '
';
            irci       postgres    false    203            �            1259    21590    scholar_profile_id_seq    SEQUENCE     x   CREATE SEQUENCE scholar_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE irci.scholar_profile_id_seq;
       irci       postgres    false    9    203            �           0    0    scholar_profile_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE scholar_profile_id_seq OWNED BY scholar_profile.id;
            irci       postgres    false    202            /           2604    21584 
   article id    DEFAULT     Z   ALTER TABLE ONLY article ALTER COLUMN id SET DEFAULT nextval('article_id_seq'::regclass);
 7   ALTER TABLE irci.article ALTER COLUMN id DROP DEFAULT;
       irci       postgres    false    201    200    201            3           2604    21646    scholar_account id    DEFAULT     j   ALTER TABLE ONLY scholar_account ALTER COLUMN id SET DEFAULT nextval('scholar_account_id_seq'::regclass);
 ?   ALTER TABLE irci.scholar_account ALTER COLUMN id DROP DEFAULT;
       irci       postgres    false    205    204    205            1           2604    21595    scholar_profile id    DEFAULT     j   ALTER TABLE ONLY scholar_profile ALTER COLUMN id SET DEFAULT nextval('scholar_profile_id_seq'::regclass);
 ?   ALTER TABLE irci.scholar_profile ALTER COLUMN id DROP DEFAULT;
       irci       postgres    false    202    203    203            �          0    21581    article 
   TABLE DATA               y   COPY article (id, title, author, date_submission, reference_title, reference_author, reference_year, status) FROM stdin;
    irci       postgres    false    201   e�       �           0    0    article_id_seq    SEQUENCE SET     8   SELECT pg_catalog.setval('article_id_seq', 2016, true);
            irci       postgres    false    200            �          0    21643    scholar_account 
   TABLE DATA               :   COPY scholar_account (id, username, password) FROM stdin;
    irci       postgres    false    205   �Z      �           0    0    scholar_account_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('scholar_account_id_seq', 1, false);
            irci       postgres    false    204            �          0    21592    scholar_profile 
   TABLE DATA               :   COPY scholar_profile (id, name, citation_num) FROM stdin;
    irci       postgres    false    203   �Z      �           0    0    scholar_profile_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('scholar_profile_id_seq', 1, false);
            irci       postgres    false    202            6           2606    21589    article article_pk 
   CONSTRAINT     I   ALTER TABLE ONLY article
    ADD CONSTRAINT article_pk PRIMARY KEY (id);
 :   ALTER TABLE ONLY irci.article DROP CONSTRAINT article_pk;
       irci         postgres    false    201    201            :           2606    21651 "   scholar_account scholar_account_pk 
   CONSTRAINT     Y   ALTER TABLE ONLY scholar_account
    ADD CONSTRAINT scholar_account_pk PRIMARY KEY (id);
 J   ALTER TABLE ONLY irci.scholar_account DROP CONSTRAINT scholar_account_pk;
       irci         postgres    false    205    205            <           2606    21653 /   scholar_account scholar_account_username_unique 
   CONSTRAINT     g   ALTER TABLE ONLY scholar_account
    ADD CONSTRAINT scholar_account_username_unique UNIQUE (username);
 W   ALTER TABLE ONLY irci.scholar_account DROP CONSTRAINT scholar_account_username_unique;
       irci         postgres    false    205    205            8           2606    21600 "   scholar_profile scholar_profile_pk 
   CONSTRAINT     Y   ALTER TABLE ONLY scholar_profile
    ADD CONSTRAINT scholar_profile_pk PRIMARY KEY (id);
 J   ALTER TABLE ONLY irci.scholar_profile DROP CONSTRAINT scholar_profile_pk;
       irci         postgres    false    203    203            �      x���r#I�&x�>�I_&s�D?���A� ���`0#wVZp#����D��HK�A_�0s��ʊ�qeeO{�9�[ԓ�~j�02"��+"���TV?w35U5U5�O��qg�D�3����l;g(��Zw�.��􆽑37w�w��[w��Vg�v\gҧk�Fmg�=���,��Թ����y��?����2����^4ŕ\�A"cq�.�Ց����b������H�O�t%�'����#q�E�.�髵��߈�)���Qq�?�/���I�����(�z��'����P��g;,�\Oh���}�m��h:�H�T��hЬO��Y�
eL��FSn|�S��I$���nؒ�Dӿ��ҏK�`#31�Eξr��%fe
"�5Q��q�b"��Q?%Z��(�Fy:z4�F.c)����*c��P����'ެ։I�\�I�m�y��荒��Md���x*�7��l*m���ڄB�b��8Ub��AL�~�Z�	M�/�D/eST�jM�W*Lp���G�$=4/��+�^�P�Zn	��).�ݍ{����?�72�4��,\�h9K=_3Y�Ջ��x���D�O*�X�8����MC����,�X�-7E��O�$�2tq�C��nw�+�}эL�>�u�Ӻnޟ� CɄ�)�\�p�b"Nt�&b���	�B��J�/E����zw>���|���@�t�Lh �QL�C��hN��1��[���S_?��1�r)WkqS��x�5qY�	e��u,.�j�&��M�!�0P���A_/Mu�4��]�4h�^F��!k
K_9,�׻�.���)�i�i�10{W��a��޵j�h !�&2�`=Vj�%�j���*�kQ�Gf���r�E���]��t��)�N\����	f�\\ 8T9=����m�`q`��)dM�8��׻��&X�����r.秬������:��9f'_4iK�/��`8?p��������.�9p�Jm��	�g��>?}�^��Ã���\�0����&
<��,&�"�I|���\�`���Q�:1G�����h��(��h�;�	��by$\j1L}���o]ϳ:=>9=�Ѭ��b�6䪄��d��(�;���;#1�Lo�Ѧ��Nt;����x�9�tܩ���!�r�}!�����H��1ִ3c���e#w:��=�nԽ����ݨ�p�7���)ͻGlju$ަ1-�k���~\�(���8���_��������_*g�F��y1�����XE�2��^}�H�^��Z�4L�%8`��9�}#�$LrG^J-���d�����ɫ�J��K�'�ZƾY�72 ��	:T*B(r���/�4N�'U��@�.�&�bI�O"0�9�|:��$J�
������HΉ�K���$j���j&R��(Qq�>�]bt�t�R�3��Y��2�`q�U�>X	W{�rF��.O����aE*�rE�*!�N\�䀹�E�[�M#=��7�ZC������,��	�	���}5��Q�me�"���j���a*p9��WI��\����uD���$�D�@ӖZ�"f��`Jl��y3'��*]GU;��su�_C�ҥ^b\��u��*iS�n�����၊i�/���*�����)�jkK�� �٨�������}I�j�:��6C"�y�&Q ��z�*�>���n��^���l͘���H��z�y�� #c+R�)�K5Wk�Y��KBG&IW�G"���H�1�_��������bL_-��x(#���=�P圕� 2mĽ�6�X�pG�F@&�/OZ��$j�s�^�E�m�����q�z\=#�v\+�J����'���\==߭�ZE39_~_&�8$)�T!����-zI/^X�0!wO����*�4�'Ғ�U-�X����U�̌nA�v���>���F�)���(2� ��E�$vפt)͟<-��,�?�0����wL�=���'��tҨ��T�������C�c��K�W.�8P$�fN����'�u��CdV��|��첰���)�F�ZX�����Ʌ��'fF+�-W�I�]"l��]�(Is��H��]��LU�I:	��@��~J�D���@���Ҋ�7;{��l(c����p��x0䊐��Jm�T~d����-(�~��8�����I%'݇x�\fg�yjiKߨD�jXh��s�V�.YBݘ�&�1��E��OTN*��[rV����_��b��֜vA��&��'M������Ɛz%��%�3>Q�v<>᮱�³fW�։����/xf��p�E��&m��-	0���O�ϼH���+�����j��)9����?�Sr��R+�r�	��zf�N>�m���2L��)�.��"�����-Y[���ϐ��GC�(��4ۆ�U����{��0�j�Ú}�5�H8j�bى$K�<ժ�u�b�r�8�ZE�xcg�4�F7�^�y��;�c�u���&G�u�Y��l`7�ݓ�¿�pHO]�v���k�#|1F��,�]���x�C�߉S*�y��5�bks���@����j��>��p)��e�l��@��BNK����_KP�_n9ZiD�3��$'���r���i?�C.$����*2u��x���s�0F����uj"��`�?׆��MQjT;;����m�ڹ��v:m1RIvO�)����W���-�������bT�Z�燥�bK=F�Ye$�'�A�����T�8z���<�KM�١U|Cz�<d�Xv�/J�Ѵ3O:S��	��r&����G�:)W�o'�.sFS|9��vg���x��Swt1���ݦ3q�E�n����qi�'�׫#�̼4���E���>�Q���^��*��ҽ
10�t0�0���̉E�����o��N[�K��f���}�?��$EnmI�ȵ����?�p�)ѓ��a��	��p&A<�>O>��C̈H7T ���c���7�*�L/���#������r���&f�|�M^A$�z�Yʇ	$i���e����.BD�aG-9�ۢ��qh��x����+�h��5$NL�r�%���(]��VP���3&ɓ�T��t=��b[Vb}
�N�N�]r?:�$�3�\#�ۭʹeN��3]J��,p2�����[�>��Y]ʘ��kC����k<&�8��@��w�?K��������k�QrA	L�ջm��΀F=�ao���Ӈ7=�w�N"�����vw}Ǆ��xg4������w��]e�|�N_��.��w���ED[@�%ôJ��o+�$��!�Ӧ��#��������#ES��芄ߚ<-2��|��ްݼOx����z\;���ʟգ
QI-����2��n�r>�$h��[d���$z�f���mM�HR���8���&�!zE�T�_v�����x��"�x�v� C%މ�!6���lw�kb��]�N�C�%�/;ܤ���d���	ۭ-a'��y�zq�]z�7>M�y�]���Y����d{#!�,$�嵫��}�a-�����H)�6{�b21X|��ӕ��^d�^�����v1h'4��F<U����#vJ�T�^��2�#� zD:�]w��]\�@��~A�u�����Jn�VKR$8�/����1~(�u�6��>9R���ђx�YE!N��y���Ɂ柂�S=_�d�l�T����6�#��o�\dD�O+�
�O�4��#�[�oJw�� 1��N�%E��i�@�OBv�}gܯ���ɒ6W�"9r�@E�k5	I�{���x�na��<��fٝ���ˬ��@Jnt�ɷ�4�8I闃�,@��d9ç��r��;����)�oZRs}�5��g�K��1X۠�̔n+��~�ta2�8[��������o�g&��_��;�#��/��F��&4������RG��;N��$��ֺWlq��b���:eъ6�	b>�s��-�P�vzz��O��9�7��J���BCdg'��sZdO���t���Ve��i#h�(4K��:Y3�QșI#1�?�1�$K��EQy��y�[ꡚ��ʘI��:tS��9���O*�_W�P���%�2Xk�lI��%S�!��q��4w[�����Z�����Tr�U�|�t���ӳ�6׶~ơ    ᜆ��m���2��N���&��p �Jh����6�������ޛ��G�u��)�n]��Gͅ��R��e�"E���>�=�-���0����A��q�E�q�?��'�m��hIL{���m��_��X
�N!��d*�3Hn�5*_�_o$mіG��6���ʥ����JD���ƞU�|���K\�H�^ ����-��v��` �i���/��(b�6���p�e[FR���ӆ���`{��8-���N_�h�2�ݟǝ�eg�L�E;�n�!7ν��ۣ��{ǝ:4�!�+G��̗��Nz����E/X�Dn���i��I[��-�)z�� T�z�͑y���Bx_xp�
yya
�i�+uQ>�@�R�ފ!�}iz�Q7�3��/> �8�m�t��dK�iH�l=/�I1�32�$k��Ğ\#x���z����](ɂ�sם<{O-���H��I�Q�2�O�Q��W�Y�/czÞc���3ur���i��4^�M�r��=�٤;0�.��I����mK��x �
��fX��8X���yRl~�'�r���⼴M(?�#�l��@���I3��~��S&Z��y�����>����|�ב!�N���Y��B���WŻ��\��A��EGdF����Ĉȵ��������ѣ�*����q�a ݜo��9�M�7���Lk�3dh^K䔧[p��ځaC3���$��*R�3����$�
�.�+@y�.u���`}S?�ρ}�}&*�u�ı�6�h�G^�&��~.�Nd;ڥCb��5N�~�۫���U�Ü<�9������`ɉI�@y%J��PIS�����/�x�f�u��ړ�^�\�Q�C]0�8�ޙ��3v���[�����Q���:x��-�T�����;��r\i���%�e N��3y*nRD��]Q\�c��9k�����p9k�4%�m�Ct
	I���6�2\�'�4��I���F$9��٫���4~���e��ތ�w�eѸB��)ɶO���/@��I�;���\���:T2�i�"JQH@l�U!g&�.9��*���^�?+�;;UԺ]+{q��c	��9�fӾ�_?iT#�]���#N�K͚mwq�<�Uk�@�z"݂16����{RoK��y"���o�	��D�8*N{�åN��I��O?[>�+Bt�'��~�\P�+��ZE��,�A" �_�?Zo2��5(���ؒ�6�P[k
�i�9Ȼ���Ud��h����wϫ�j�بo�
�A��z���(� ���%@x�̕�E����H!��k�jBC��!X�<cG�#��D��q��Eb�h�Oʨ���=�!��npܻ�;����_ZdD>"Y���t$��2"I�^R]�*;��Z20��".sB@��$�v\'��ym��Zӥ��i��M�"�u>�!d!D�h$�޲�i�����hu��ɍ#�����n*z���a[�ADkw&��VlwHɼ��l��3�!d]\��*u�m���`tq/&�͐�55=��hdM�t����1������a��yc_F���z���ٞ��	���"��o����Pf����rqQ%�B�طkr�'3+у��H�R�"�����:-`�h�NL�z)E�ٍ��Hde����e����^�B�Ύ���o��oȤ�d�7,���IC><��<�w�h:eh	��&�ܡ7��� �M�8���]�E�ԋS�(���IS�&'.c��/=�Q�R�1��h��[_�/�m� ͳh�����0���4������H;��^�; ��X�ִ��_��<���Ћ����*.�i�!��1�i���؊9C�`�ی)�s)$��|�/��_�.;$�ߓ��}��͚,r�j��z&�}��9sS�V�����D�3��s:�ۮ��p\�:�;����^�G��7:�ZP�8z렼�7jߎ:t�6gx�����.���d�;}@^?ۍ��f����l �ɋt7$ �I��}��+�pz(��)��O�Zz�8�[� �u���Y��z�kgH��,��I��ٞO��Vf�o�A����m�Oj��X�q��� �ݢd��G�_��G/'�.I��u��/���zl���='dih�,�ϩV)7TF�����*6&N=���k�Mb��qh��|z.�S�Y�j�$�P�&9ľ^�,�7�B"�~��^/C���,���A�� �7��U�c�k�1A�"[Ym�v�B�՞�b��.ÌNxF�}� ��yGD�)���Q��%��I}�'٢�V➜H �s.K֜��/�V�Qa��x����?����0:R��X�1Y���*��}�C���+-ny����>O��ĖLU(f��O�y>?�ŵ	oi�`������TI�T2��N�h>#C
�8�R�4(��������,6�:C����c�K�8]�"�80 ��@��%Pt��Ir�l���J�	����˞{$������z�j��;�5y��y�@�6��	���GZ����,m�96J{t�ܢ�[[?�CH/���r���w�S+�m��m7���������~CS���X��dSTG�<�񍝣RKgpX�_�g���2��z�0L�s���S��S�fg�G<���_z;Eμ��*b@���:���K�Էȏ�2V\��}���c������ɥL��Q�kƦ"6��J�c^�f��`�/��� �@�����S灔>����[��wY��\���YseG�#�C���c�7�4J�o°ෑy77�lo��'M~���*qU޺e�Ӄ�|y���4��A��ϟT˗���I�q��/�j�"oɜ8v�i��	4��4�B��-���oS�*���~������wh�9�`��������u� �$Jm�p����k[�c����~����������Nb.��-�a�V��N�Ex����_~�A6%��y��� ��zr��/�V� G�*g�9�4�|p�ʦ�쳤�
]�a�_��������Ds�ҙ@n��Uĝ�9��+��=qHɖ(�d�	\����M@�x�>G��4h&&5L�&�4��ޞ���1a��pe�zAQ?*R�*'�����J� wZ��S�>�l]t��w�GW��A�n��a���jC�ASԔ�r��G��KyI"���j�@ڿ����s� k�D|/�'�\�����c'��D�sA����)���ځ���j�4A�R6eatα�fa>ک�4�[hz~*J}�U�w�Oۊ�����@˿I�NQ�jHӒ���t�Eә��F%;,�8��o���C�3��h��ɔ�Av����m�h��@ֿ����̗��\=?�o��k��l��O���Sr�-䬟���O"�3:*o���Ɂ��`�6Es��3�6�UJ�@ǧ��>�S���A՞�
=�wCM:#1p��c�#����ӛ;�v������E�=�xD�n#��	�=�H����4HA{�sz��wr�5yv(Q��Ub�=��1l�VQ�V�<��FE��v�q�J�>���2e��� ׸�"g�.�nD��͟�>H�uT�Uj�}���\~<��ТzY!}*t�쫵Z��Z��J�R{�G]�Q(WZ�~�Mu���e��6�E�-�Z�2��c����N�fb��xG�v-g$�����4w)m�NzBR�5�enc��<���H��|���\��U�UN%`f�p(����;�z�/����w���V���t5K���X{<\;ߗy�������U�8o#<6�x1 �i��^΁ї�o\k��Zꔜ@�B��nJk�B�i:K�k��[�L�����H���}����Pؖ�D��-�R?ٗ�g��P�tZ<*����U�0D�ɠĬ�1T�����M������o���muh�g��h��3v���4���ɀ�/M��-`֜�'dٱQ�������1-ő�?�������,-����`c�33ɮ�@'��1��8}��7��n~�R!������p;���E.�e���;�ҵ��T�!���J������j�Q9��������Ҩ�;��HF���K    	�&5=�Ԩ���`�K}R�	D����(���O����i���d!-@��o�	�W�L~/�M�m��T�ߙ��%9&�G ��{4vg�~�E����8%��həy6p�P�mɅ�Nx���������/-��X����潯�$P�y���V��/~߁��ڥ6�ih�RK�/+�D=r��#��W��״!�'C==�}�z0Z{߉c����ҕ^,4�d��|0�,2� 5��uOɶdP�K&����%>Q��p���<_E��{�ܦ�:�����h��u�w.�ۗ����D��m�@t捎 �qT�FL�j#tl�h�KR�d��&��ݪ u�Nl����h�<>���(p������A��I;s_+Z��Td���f
Mj�<t=K���$E���,�=Щx��Ms��i�ۦo�+I�.�Ē��n��p���� �$8�}�Dc�b$*呹��Bg~�(�� ����b\Fe�@" I�޶�Ƕ�i�ۦai�%M7
((OA7)���M��1'z
50�'W�:=��i�D3�@Ɂ`C+�������H�8�Hљ��pXO���N�w��6�獌璿�Ҏ��g�8�F\�y_�4W�a�p֑�>��Դ{\~��οm
����(L�1�C��'mВ}��]\|����).k�V$�$���fʛL�4k�|�4��_y�	����i�
J�^��,f��Xz���[�u'u,܊5�ɩ�CUe�KɝbTq�l��Rq��G@�D8�6`vp6�#�N�=y���r��1���5B!0�����r��G����>!���wP��YP��E��2J@"џG4E�v��Y+W���/2H�R�A�8��D-9�m�+�4�K�h��J�0�c8{�m��F����G���BI nt�i`#��w�w�E�ח+�'�+�z^Ru�t(�k-��E^մ��z{,�h|� %��@%J��Yr�{���F��IC�H����:yGs�]���8����0�*�k<���N����٘�X m%⥊�i�TR�E�HZ����??W����������b����ۢ~�m��VV	B���N8�M"��Nv!��&��z�-���]1����q�ϙ&V ���43�.f�-3�tA��/B�<h�ƿ��M{!�p�R[>q�L���2)��̝�|��LQ��<9f{"_��M�c"�(�wM9�9z�C_g�[[d�E�������e�H�x��D/"��\"���8A���E	�;Z�"�����|&L����ۙ�ᳰ���ad��R`>�ܹLF�Ϡ�#�s��4�p&����0���P�č�7*\b���2L塉"@ �K�b�E9�ś���gս�4Yh� Ҥ)*�ҡ�UEK�{��5v���gE����w�"�/��%��s����ܰ궯�L�Ofw�����}a/�Ví5xv�w����ng�L;��#��ƾMdw@�v@�b@2����7�ŭyoK)�Q-rZ��J�
�JܢU�w-�Viڛ���T��[86����1T֌�;��1ַ"�椢I����q�M.�s���GwM��_��B��N�wt.o�bc�H��z��#�6E
�n'���g{9(ג���'�'z���χp�����A�d�]����6�L��a�9���v8E�'=3��=�9;?���M�ҽ�ȈI��qD��AY�ַ>�8P��M](I�?ιu�ʈ^�O�t%ߡG��ad�m
��Ɂ��nb��n��g�&�r���ħ�i��R#s{�>�k��6�u^)�����?b���08�CdV�l�
aEkz_��m����ou�s�QR/ch2�ٽ.��,D���4�$2���/Jx��.
�dڅg�QÿPp^��ul���E]��W5Dr�|�kr��З(�b�NE�g�9OV����u�W�]Q�c�8_g�����3Wq�C�o��	2�P�����(��}Ήe'��k� @0d��)��F��h�wr�Ϋ�>��'��� �6�5�v��}B.۶G�՗�Q7֜!+ӱ�� ��=���f�F��-sq$��jC��
� ��/�+t�82kq�U�����8�rnW��O�"nL�!���۽��'���Hb��I����`�S�����h�3���%^������]�689�s_4�jV�+�m��������\I��>�9;�L�J����#�/�o�"g�g��b�!�ِ�Vb�q`\�^��~�#*�ɍ�����i�vzΰ��<���}Yޑ��2��<���;�����y� !	��z��j�x��d�L�,Xo˜g�<0�'dN������.T��7��*���ok?L�m�Ú9ϗ�j���p"j���yY���jC� *���X�6�Kc�����!Ȇ烧כ�T4�xF?��2��5�ɣL���~��>݇nHs�vѮ���=�Gn�
���Տ켥n�ģ!2G8��6|�d^F)��|I��U+��6��Yʏ_�-!���&��(b��3#a�VD�V{�����GN7r��\�i��	��%✀�9S��x��a���-r�"�P���,�,P�AX��j��я�g��-��YwpԻ2>�g�piƖ��>����Lj�8^�zg��8����?���c*~D��J�p��Id����v��Qaۈ('�]������EXt�a��}9��G��$�z+�6"1�8��N���)s+6��e�#�` 
E\9Ni7Òϙ+��PW�ݖ�{M{��rf��&�}$/��ߑ��[Y�%�q��2R����6�Ww�Т))i��̽����ai�7�~Y�����HlP�#N\>~d��l���A.r�G��
�2�E�B6'*0'�Ct��^_��vQ=�A0�h��/��T��2���s�8H��V���I[;H�AB�h��/�(�m��{\$.�"���q;*�	M��{Q?�A@�h��/��P��ʻ �T8S���k6���$�cQz_���Nfs��R�\�� ��Q�pn��� �qޣ��8_�M�B�k�w�5�gRW�����6pnp��6�4�E$��B/�1�\r�"����?��ȷy�d���u�� ��g�I0/�j�-����.>�[���.|�:���~����*��ʸ�ǟ�{��������!���k%�Pi��qQ�4Wh�%�`(=n"-4�P������Թ����m=7�}��N�F�pa㠃:x�ƿ�:�F���=�����۳�ҳ���t�ƿ�B��i��h�+1�^�4���}E�%��R�K��5#.� /�x��n� Mr�� � ,�^)��P��	����+cq�g�jH �$��1��6�����fkyE����D$��6��1�.���n�D�>fKl�Xup �郗�i$W����O���
 ����腭v�b},��=5�o��#�K;�w�{~h��|O�
�坰�������{�����q�Yg��wǚ���)M�XS�&�V�8�4(O8�&O����Ͷ��9p���-;�0��|r�c��?&��摙i�)o������������3"3 ߋ��f�9�Z�:@afbO�+���7`�>]�� ��}�<Z9���ţ%�Yn�[���'���~e��:\�c�"�~(�^o2C��Lk�u��ֽr*,<�|/J��U0N����.��y��_���J=I��i�"��J+�$n��@k`"V� ���`�0��e���N'�4�r?�7qAP@EVO.�ʸ`�U+d�c��Х������yx�ܵ��9�Snv�Mn�vʿ�6�;�~P��G��b�h\|Se�-��6S���iL�W?�{FK��w���}�a�n�-��rڒ�i(q���z����A��2�sW�\A�����~ۦ���;<pQ�w����t��Ѵw;�c��J�'No�t;�}�N;Cqu;���
��t��������`�{��o������@n�Ψ-�Iǁ��%$�Ф��a�e�C.�q����	�����PƑ�~.'�U�W����v1��Y��8�{fл�kN�)ra�    <�Z]����<�GjN�e]Iz�Klk�ħ]�.��0K����x���"�r�WT�biYj��i��̓}M����!��ܐ��EH��\uH
66A:Ӵ�o@��ʂ�ʾO��  ��'�8/�e�y�c��Hv���v��o�i� �J���=wP���1n�t�wˉ�r������Iܺ!�ʕ����%��%��D�(�E�	I�S(�{�����諉��o��J+�Ok��ʗ� ��υ�!�ܘ)Q��cH��%}��@A�x��=�s�(���+�y�����m�M���3i��a���4VB���(u|ZeyjE��;�e4�j��U����!�<M|�Ͱ����/~B ��_���3�G����6�E�C�o���Vq����;fY�܎
�sB�o���I&�}E:�;� ĳ�<%���^��ϖ���C���ܸv�����܌Z�
z}։\*�L"��:�~�%��Գ�~JL���28���I�;��#fK���'�W��cY�#�`>z?�d���
�J�.b�����+*�bh�$�`R��Y��6�9<�������]%&F24r|L��۔lv�Mw���7@����;x!�g{E�������ｼ�����z����m����)�6��2�o�=ĝ2�ݙ������
8V9�+j�x1e�%�\�(�YfR�c�Zf�dv���tAb��"��t>���[��I�J-�'b_EE{�j�Կ����vFm"M���K���&�5�� }CF�n�fg���Y��riV��e�G�SP�cX�� qѦ��->�i��@�rU�2O���hD������.�	l�1� �=}LmrNŊ5��D/(��ę4��JF�]�m�y�j��R���L��D���R:S'f˹v\�+5�h��Z�޳����`���KI]p'mћ��I'��iV���bz%�}�Z[���U�j��\3��	3h,��!2�.ibJl���ڷ�A#��lb��g-lm^�0���]F4��9�L"���b$�.�U�}�}�obΰ�v䙌�E�gsD����H\�6*��e�eL�C����)[�mt�~�R��^.�6�h)^�x�v��&�̚�����G�^��s,�M�<$�h�W���b���r�~'���YL�PM�㖉m2Q���,�5W�Z�W���j���lI�³�AƯ����si�r��Onk��T��q��1[:Ζ�6K�z��ZI��@�u�mVI�P��@m���tԕ+�L�Rx{�uF�'��k��s�r���EXi���f%�&$S*�m�����wF���,B4o"�;<�X��s"��C�����>c��L/}m����G���/*�]^�Ì}Hb��o	~��k����D��ߵ���=��3���X�2�O�������x���WĻd+���Xĝ��yR�������m�[j�={$)�X׶1��n�� Z�G�n׈cp�����l���ёV�/�K���{y;�@0b�6u���������3�+ѴH�m�Ջ���E�i�¡�chf�L��$��|��ѹ:�$P�&p��WYlZ��F�x����)�g��bvh�ʇ�eC׎рn��v�)鐗;�
�q�w�a�"�$���Q���Z�k>��Qr����K�N�>�DX���RaC�vr���ive ��K��ԫ���+#�o�����Z�@����,��:�HU;���[�h�xQh>*��	?NB���`��;=P�����;x����A�͒�5$�8	; !�ә�;;P�7��C^�K���ܞ+Ɲ���n��u�=��N�+�:�;�`�O:ng4u��+4" @A��\g�z7Ҝ(j�6!+��lwH>�A�U�Q��%|�g�v��FQ�Pnbԧ���e�^�O>��-�e��Q��7>*d�c:�i@.�~!'2_�G��P��'�۔<E�'\�k8���r� ߱�w�����H�ܼR�:�e�h���H�^���7bT@8W��ҥ�������m)�����Q y��ʄ��j��cӓh���T�h�`]��Y����h!���- v�H�� \s������`�[�s@�����S�$�+����	�5(RAf!�i�÷y	́�C�0xH��_&�"�U+E��8�8����C!o4���'��ߙ'��T�8�g92�<��Ȉ��s.ܡg�k���L�5�G{��;ol
�z��^?>< �Ҝ@�Z�NT e��C��/��hN#�Z��o�ۃ���e>+˔��'1�z�TpΔ4f�%&pw���z|����Y�L�r�"���-P?;P�3S?&���G�iH�	��%�oȎ�1 ҄�e7��bZ~�X��4&�p�p�����yy�D�  �Pf��[���EC�Ub��,�v�l˶��in_�q�[���#�m��o������z����wM__��%/8ib2~��=\@�-��;b���Q<���cJv�ˇ��fw�^<��*\x���U;ê�̒���R_�(�>xU������tzQ)�i�7;�.36�>�LZ�)}�v&�޸�w����g긂>w�9Y)D�$Q"�kdT-�9�1Qp	`��:.GG�̧�K��3}K��0W7���6[����Y�4FK�r���vq�ߓ�JmRg��jV�"��:�l�9Ϟ�,N@��d)���f����l��1!��'#~d�9��ņj=���ai~ץ!$�\(�=q(��Ģ��t�� �����k��D�弿-���a!��˻yTO���]�c���C�i+��U�]W����o�;HR���"�
͔YUg���}�*�A�_�s9���!y�ߟ<Z��W�QƐ��wG��9t�5Q/��;(�M�-��\�%�0�M�lT��;��?�&@���!�+������z��p/E����\yf[nި�����ItL�w�u�=�j���;��f��Kn�p-���b���=�ړ��˴v�@���& \����J���ۺ��選q��gt0���	��}|q�,ۉ�Y��?�� jwd���ܒۺ�g'��c_�Ҙ&Kڮ$9�/��li׶xg�o�@���G���]��Kd&*?�Kl��� �&��U=�~S4�^�Nz��"���BW-�;-9���xK����R��Rj-ճ�7E�6�_C0܂��y���(f䊝�<e*�YZ�d)CF0Y�y�E�q`8�ag������/׿)r���� �!�Ȋ�͠!s���#�>�b����i��Q������;����,s�+tO��*�]��c���ϋ�������K���؎#��m�8�nI	S�8b��`^p$��!��_�s�e-�U�H9�dg'�Ϥ� M�Ң4�䳎�)g9_�ey����5U�#]����d�dbr�k2�����H�:��]#�5o41"�r��Գ�o�f���~LM��@�Ng���%=�EW��� d� ��&H�	dً,�g���o�t� U�v���`2y%N�E��{N�Ng&Z�j����(ti֛H/�D�����\k[����5~,J���s� ����"S�ųB����z�ckc�%�R?J�Kޤ�M <�|C��#;R4�)@�Q�Ai��`
9N�a��7D�l�,� �X[�љN�H����)�Ͼұ���KqE&�r�v^C�mo��;SN�}�ס��n�G���3��H;gp���ñ3q��7��8�����AdՃ<�����U��zI�[�QBHS����*��;�_����L�C�w� ���+`�*��pʓ��'�͛����V:$�4q:��o[dS-�++�k�ҫ�ٜF���_r��$��nC����&R��$��m��L�b�m�9n��eȥ��:Wno⌲!C6#�F��ɇXð��?�7$����O���M`E/���#Z1HI� �;%ґ &8�"?,*<��q^U��G��2NY��k1�K}�?����z�J� ݤeҰ�`�y��Nwʷg�t&_8I�lȳ�+˯c8�j��pBD	� �]NJ�.Ab3;WVE���)    ;�L΄�G�;��䯰H���^�:/N>?�Si)Ѿ2L��� ��1���պ��P�{�9냭���>�6]ߛ���	�sh�K�aS_�V����rq�j�C�/�?{X��LB})x����r��"��ܢ��R���;^ gZ4?�.k�Oy�ӥ�g
�g5L�#5zaB?�1�Y��4V:�����YeSʖ,{��je��0]b�G�YzѶM�E��N�g���eD�!��nM�-�E��.�Z�o_Z�i�%�?��]�7���J��LI�XF��,I*��E��[d�X2Q�=2H�(��igr�����rܷΨ�qE���vO��\z;$��o��h9�gBo{#"�5�C�xH����&dB�t��h�1X����f���su��5A�D�
�'+���8>�n2�xcC���U&9�8���Kߖ�+��i3���bs!.�(#�۽uo�{��-n'��{K6���,U�3����V�h��ڽv���DoԾu���S4���w}�/p����ߘ�s�"�W�F�[�|�E��k�?�?'HW��H.�3���T�5�/��g�����=������D��?bdV&ڙ���L��$"V;9ٛQ��o*�b�E[s>8�C��2B�n+�@������TJ�y��G�!�w�Yu�uo|;�������)����1z]8wS��8MP4~�:��<ܧ��緪w_�2�XV�K���՚��|CU����x�y��0*�$�p3�Q�ȡ��~%�,#�f����aƶ��d�}��,�S�+��]����x�tΩц�UL�Z��9TL�OĝS�#���i�ì\?3v{q(Fn�~q�W;i|d)���*�k���������W2ɱ
��(3a,_�%s�J��!^uTD%kdk~���dI~PW {p;k���۹��i����a9���=��j��r��˷�׷��E���p<�]rc,�';Ѹ�2�ͩ�Evj�'_�6qU���(6 ��1>��ur�������:�S͙�W�
I��<��O�B�b�d����������N�����&�	3��ȼ#��؉�	�v��/;��4�@��y��Pb�M�i�ۏb�R�3�,�E�V�[2&�Y�1�51�p��'V+]�3{X�$��$NR0��.B�~�'�aЇb��}��;��o���Z��t�~U�h-�OR��Қ��X!W��0�s�1r�%�.�͊[7���~���3�%�̽?:4#����i�U�ю��w��V�$@��Z�J���l��(]��="-�a^5]���w�*iڄ�����[��q��KNsO�:�Τ'�޸7�M9s2��,����o�H{:����6���F	|2�ywB�/ǕG2���,Q�V=��	I�z�yc��J�0��je�'�g*y�2Y!��,(����'fFB.�8���d ���|	�b���|�$zK���7G���8rV��ziqL~/��b��m;x�72H�'��w� Dz����J�r����:�}~��W�l�7>g���M_Fk���^B/�iS��#гi[��\m���䓬e����ő�=���H=iڮĴ<*w��i��~e��Ұ���~(�+�	��Y0�<�Zm|ex9�¹'����9Q�����4��=�pn�|ۯV�ǈ�����撼�F���qF��3q�ΐ�؍3�����vD�3퍺|�0�֛���'�H�u��vO�I������o�������q�!~��\:CNvñq�~غ�vF�0�"+���>ť!@�G���c᳒�$m��<�����1AJ^�T-8+�E���;1��|�FM%y~k"��(�������O��\�8��O�����tc�~��4X���0���@�F�D�B��4V�^�5i��3�P���8'c'H��"���< YK��v�rj'{=��q���(���[,�M��k��UW���\�[�i���~f��i]�\�Av�{����GI�Y�A�����X�b�0���^IҰ(E�ժ{M���v�7I�_�H�'����`�q�tk{=]l���u��J�-}�������\������l���!�T�^iIr�*�k�ws�Z��5	KC��j��wQ�����h�����Z�$ό��:N����Ȭ�*e��p��>���:3z��ZO�B�[�Z��ה��x��U�i5��KCΡ�� P��"�V;�k
�ԡC~�����l�N���N�Ur|"��1�����ʇ�T����,�-{7���P,����"���y��z(c���F#)��&FF��&�:�lR�>`{�=#_�1�>���~��*?Y�e*Wq�<������Ol�����V�wG5�W��2���$�*�r)<f�yM�&1��	���B��5��zb��:\��R�E=V鞫�w؉s#k����z�+Ct��*o�^���!IY��5��N�2Q�^���r��+���<�X�,P�.#�Ý����\K/V3K�����?�q=�%7'w��h��Y;ߖ.ed����>:��\_�4�'�J�jt�a���������ύ��>7~�Ϲ=�J�R �0��v�`-WlNm�wud����AW��✢3�/�d��%�9A������|Z�"�'Ȣ{�d������]y�N�n4uZ���b�{�� ���-�KDN�<�ٓ�j�[��'9���C>m/z�IP��ӷE�a:�c���YC��o��P�$��]����|S���-N�<�)ǚ��-EcB�G��$�!;��m�s5灾̒���{�mB����>���V�+l����7F�Rv_ x��:�x`��6����d�N=�<;Y���o�[ΰ|P��pM���u��i�~�E^��iր��t�L;��|Hs����I���4K���.M���!�n���JH�]�5���hS֒xF��J3�Wߗ:J����v���ϧ�"���'\�N�d��:����!2+�'�Z������d$�3_�^u.qؒ>�y�r6�V��}v��@��9.����yX�{���Q܆h!*��Ӌ���]!�C�t6�7\��I����5���׸R��ek�7N>;m8U�j���x�I��A�J%�����|6 ��֯�Z�J�,>��Is�&���D�4 
��X�GbJ@x�9����!5������X���2�|Ҭl�ZR�-��5��h�:&B/���V��dl!TL (��,��*
K�Q{3�12�/�ۅ�\�-�[�Y#��J4�M'&������yt�A��!HU8��á*�����__<j,`�H�R�H��V16N_ń0�+`A���O/�9nm��zoV��v�Z��f���r�[k4^�Ԝu`s��a��'�}���=l!Oq����wt�`<��n�q�*fT���~��Kyn�O�X�_�Zt0œ�>Y����H�Ed�9�^��݁f��	���2\ྲྀq�*f�#-0�����9�D���I���^
Qю�U;�l,���>df@𿛈��4 D}!c��5M8��J��lɕ
v����bu��*%w��� E����e�����k��E[Tl�~Q� X�	�*
;�"T	C�\��m�X�#�~�s����H������M�Dg�s�K72��hK`'��4��B+����Ǒ��������@�0��dV���
�&} X�� ���k0����I:��?�^�J�#�7dV~�#�=ҳ�*NN��p�v�=޶RpI�ms�ϪA:�A�>*HN(~<��F�T���ܼ3+5��Iy2 ����x(.�&E�w�����W:���z�MdҘ�zuK��yZ>p��6IVDrg)ar\;?-�0�|��?��TD�\r�Q2��1�X�՚٫�o�:a�y$&x��#>���R��� ;���'72Qp��K��r-��[���b7�iH���'$��r��0�{G���䰱���!�?�I���8c(�l{��K���䉇�fǾ���A�����f��t�x���g"}�I�!}�,��y:��A�>.O%[����xM,�����a��y'����6�pvz��X��7��4	�܇�ܕ�\K�£ﹴ~���!�k�u���l}T�*G.M$�彂��ǆH�%go�    ��v)�$,~呷yK����E��+����|vvŃ(D񣢸e�g�w��4�`#�5��ǧ�f�Z�'���8���.�CȟY����1?��q��]��C/�Q@��܍�5>�Ry�ʃT~|�t���/��M71j��, �R`[��&]����v�ыRˤ4v�V�mÑc�][Gr.:?��(hC�r�@�#������~p<U�P���؅Y�����_12ᱸ��W��I��q�����V�1�a�"�;GϬ9$�Mi_�����V%��t��Ռ�-���ķ�Ee�	�,�±I�6l{zV�6�[;z/?�3x���u�:4��4#�F�^��]h�X�����L����ق��V�K�X���$s�?:�����b��I����թ|�� Nl!(ԌkB[N�}�����lmy@��/Ѷ_���M��89��s��u�c�.�4�dq5��T⧱h��
h?pr��.�	�k�$-�7nGN@Dt�m�H\Q���m
�y�@���4С�kl�w���&�KfQ�1��t���N*�"�;O���"CU�~N?+�g�$�8C.�aǤ��%��[��Z�g��d ӆM���o�j���==|�o�E����y�i6z�'�&������|[c�iK[��M�>��&סT�G�-2�ah�~���W�8�&��H��{� 7����F{dt�p*�O����:��ag䈛Ψݙp��k����ƙ��E��a��s�mn8$w8��h��{S�8F��ʙ�q��#�}���b��ع��i𤧶*y�uF��Y����E�+p��=�5]T�z������ �N�rW �j�Ж���Q���}�(�F���ᢺO$ڂ�Pxf��s)�a����J^�a�t�.w&[ۯ�f�� ?#��VW��iWۨ��E" b*�%:�"_�)����t/Wkv���&�fA"�7-_I�'���FJ�[���$R�Ёx۾����B�i�䢾OtnER�4Eq�L�T� K�8'��%􋁒��3B�2F$k�co]��������1�a����i����1�27�bz��t���g{1�_�����J�-W�R5|'ƭ��?Miܐ�^�D�`cOT$挏���,��5钀Q9��Z%�!��$S�|8�0�y�D�Wx�������h~<4(Z�91`��� �`�88A�r��~����6a��9��?�8�{�U�5g}!R��+R��''{1��B�Pld咔��+�r2����p�alҨ��W'����x�;�@�<��I �K"���dR�OH2c_���Д�E���d�z���C�!ܓ�u� ��W�xY%�E>�&Ͷ���Qj't��nm��]��;��Q+KĢ��N�g��đj�f��ƴ���A��͞�������hI,����O���Q�#�I�F�5L����瓷����f�#�n��Lv� E#Z��V��CPS\�'�g�[��B����(ҋ��6�mќ�h.7��`�w���	�m�rM7��r���sOa(eBn��K��)���;����G��*&0-�+sQʐNz8��S��'g�{4�~o�؏S�4��.����~{��H�2�/���s����OqtR�j>�6�H3�j_����Ä?v�� hx���~r��G�Mz_v�~9h�g�Es�Ht%���6[�I���c2��c�����'��gB|i�^��}͔3��hi�H[��쀂p�3���� ��0�#1�D'5c�o�pn����Kw�ȥN�3T ��$]����#�bm���/�4 �L4�h�D��*��z�jn��o��@��c�:ҁMr-��_��0��FF?�{i��e���K�:����ԫ'%kyS�O�ɰ7�r.2�:;xSW��������`���\z;t\ѿ�:�7��`�A�Cy$F:�Y8�b�mm��Z�Wj_�� ��*�|P	+�8��� *��nh���!9�J�n��4��by��WG����7���|ڀ9�k�βH#�h����]rҼ�������+�_��~1���g�ߑ7X��Y���P,TC��e�b��`J4�:J�5���uB�!S�wߖ���^GF������wYn$ɲ���^t�K��x�ɕ� I�`�3=�JF0%L	�)�d�W5]5�YͪE�S����lZz1����E�����s�^�����̊ 鬨t�a0S����s��l�M
D��}sB�Efd�n~�6������=�Co5Nޜ.Pӌ�*Z�ee3�63	��̡�WE��:���p��Q;��^��6{1g�Q��wSb�@�MHI�,�<���:r�"A�W�����-���ٌ؊h�y  ~�Lj���.K7����*���^ه|�·�V%���`��pFޒ�P��}7��9����x�x�q�r{^t���Tq�0�j�A+��g���������#bk�g��ˀ��!,8-IR	�PQ{ز������]��d����dO�\��[�o��u��oD����Q��נ�}��M�E�$[	��J�Z%��ﵝ���ܐ�;�||��k��tT�D�K�����v �#�3��j�_���D!L|�����oWP2�$߬h\�Ӑ�� �7 ٦�l�{.?k%.�bv���>��%�H��2٪u�|#§��g�辌���>��{�&�2�ꕶ�s�:q)��a�/��1G?�A|:���&���꧒Ể�[�ے���Bg�\& �l4�73 ���E/[v�[�.$خ�ɹ��	M[��jmn�߈\ܝ��f���ڄ��L������7����.�u�y+]O��EL���t�2\��G���{�<:�GN$Y�ąf�5ʶ> ����i��K�o΢��q�ÿ+�z��7"��	"[$��ª�X�MO�H�Ů��7"��|�\b3N�&2�31�Y|�r�~G*@2�:ۃHtP�e�j� P��)x���|p��n&����q�%���`�˙৖ޙѫ�l1��6��o�w�uK(#��FR�`�[
<�MC;�����S�
YI�Z> #��L�Y�-�b�d#��9b.)m.t��	�$�GRR��6۴T��<z����'��Dq)��8&�Ȭ��3���$��0�#OԘ{͑�f��z�V>���Q���g���|���`��� �rC0�i7Ǵ�}�J��M���7i��<�vƏ�a8`���J��ք�jv��Wp���=x���j_���8ǖo�X�W*%�Z��D|���b�浉���M�z�~Vo�=��*d��q���ىV;��H�t�6�|)�����]]����Q��f�ʯ�S�&\��]1�x��J�e>@��J{x��=�Og��-C�	֎@�b�Hޙ���}e���g;��i/��m�n�5_/�ң��"���m�e��̭f����rÉ�c�J��l,��[�c]!w<7O^� &�,��mGj��%c�9�l:Om8�~�%���i�kZ�qQ�j�������+�[�.j�#�2E�V��WFF�c�S��^$����w��F�mp]L���m��g�&�'ֻ�j޼e��iL��ܶ�b�:���*�Hs	������3x�U�7`p�Ƹ�9��Q����)���H��O�'�C�>�:z}w�*��խА�� ��Y$ҧp9��_I��9g��:l��|i�'�����;�5�w*<�NC����<B/���V�-ȑyHpǘ��r����KF�R3�@�V�UU�oAn�Z���vv�'��'�Ӗ��|�@ 8y �Cg�������/���}�(_o��oA\�L���	Ӓ��1�R��Ѷ�h�G��$���l�V��~�P'&���'�8�P�ikK'�Uo���c݇k�?�i��!8h�O�>�c��Q Տ�,�=��ڥM[c`�`W⻱���P\���>���Of�+]����S���AX��'��=�i�|�	���q��ɦ9tW~jS�r�V��f��yk���&��&"��tS�UL
$��.1��&I�%�����n����w�UHmiO�g@�L���"�}?bԷEDݣ�x^�ˆ��QS�����Yn�߂�ݭ�CN;    !�����K[s C�@4����y}��G���I���{7�H~棌��)96@iZ����|�ds�H�m�௶	�?��Y�lu߂��I�g�GM�.��Kq��>�fn!_��s��R>VY=��T�����QqHm��H�zqɡϥ�����x�n�=�~� ����Y�|P.������k�|�>�zf��
��cj�C�1��L�.�;��p@��������.XԞ�ԡ3��5S���R����ݙ�e��J�?yu�U�Ui�^^�l�אM�a\�Gc� 3���� �I�k</�0[<����N����`D�覰�ך�̰��Ċ�'���^N
��V�����ȲE��ߤ�b���)��6�:��m$�l�������4ڰt�޳��n͝��䧧�ã��&����gX.�4�}�+4�VPݕ~�v�Wx0�t[��9��-������{n�����5�0m��鸩�v}N�j7��.�&"Up�{#F�A�=����m�~��/�&S3���l��œ��ެ̿��?���N�u�C��p��ڝ_C*�����XhL�a�tƴ��Ҫ�j:zU�m��*m����m�$��M���)L����1Rkk��a,}�Y��馑��c�>�|�^� Ȯ��t9��#�Q����G�)[�����Z�tl�.��![��&�����+?0ѡ6`o�щ.���Q���������~i�}�"����^֘�O_�`f
�AyQ���������R01;������?mQ���~zua�w�^J��{��t(�ޢ$)nB>+jŶ�i��V�Ӿ��	M�T��?%֩��S�ae52��`��̎�-"��F2(�J�^q6�>(:]�?�i�����"���P���S�Z���\�����0^�Gm��4�I�����"||u�/�w�G9_R3�(V{q\g�p���!ܒ�o�젱�bs)�1�l��~/"�"(`W��%�)GG�����@�n�hyP����N������fR+�W\�,SL�
]h�zy[1s��Ρ�}��)����{2@�W���w���-.��m���	�4����J�� �qvI���E}�k�P߈e;���݋�/�oN(T5#@�L��p���Oӌ��$0�ԥ�F�l/�d���7���y�>ć���	rm�����}:J�FoHgfʹǂ|d�J���`	]K�L�;+ߓ�Ԅ8Rd�n�+���+��HS� �Tr�mQ��	O�p���0#�� ������8��
^0�j�᚞ϙ� ��ȼ>��ʏyHTF&[2JȨe;��xF7���'pN�^�B3�Fe�u���q1k���l�s�s�.�/Io��Ȥ��2Y�i�dr��4`������K�K�V����6bR��g/���qv����@��u��_��ƻl��f�,�<��{�.�/I�g<�Q��2��vz�:�T��|ٗDfi�8�f|��r]IڏޘG�=��N��tBҊ@vV�ew[�r��\+a�'����U7�
R�yv���n�]��rI.4����W2B�>G;zL��N!���3�	P��awT�-q5Fl�m>C����<�	8[�����we�7[�ۋ��t�����ʧUv&���n��[�YGz���95�j�	�1;�q߹����~ ��D����n����
G�N��g��_�v߅�z)�	�\�T�b� ��K��B��4�̽|!%GyU����C�(lc6�R��2��=y��A�Rc�?��+��p��s#���1͆��w��說$D��Y�X��u��EJѨK��_v���#XL9�$��?�1��x5��mI[.cIsU�؝��Ưrbݐ21*�*�4ޅ��'�\�?Q�����]�Q�ϲa�z&;�Dzʆ92Y�ld
Ys##�'OދY�0:P<.��"{��b�]�`�ۨ�����Z>����Yd��>��U7�gyfg�� L�ҕ�Q��t�	DÀYΦ��u�u'V$�Q��&�j�|[��z���01�j��H��S�
�Uի�q�׀$Ai+%
�<��a5 ��	WV���;���4�If�W�$��8s�k�a�Ғ��u�~���Q0�{�Ϋ��\5�~���)���*͂�l������Nm0rsg��;G��;����
w0B9������	g��3�]��͕E݅
| .-`<�B�W2���$GBBr5����2�`��M�W%sl���Q~�A�گ �$�W��U�O��~�k���|~�qk�.�����p�[5W�Ǎt�s���$>��I!�X����䐡x9''/���F��NG'��G�\H�)
��;�4ebvm���b
���~]�=����t9KO��`6��
@˹�Q�[1��� ���~�P�f�c�E`��Ѱ�@4�U�jR�%�G/M�ѩ�҆gXrz${
qX�����fEm��I�0Ȏ�h�"��^�a4�%�u�)����K�L�GY.K���a]Wm ^�7��lV�Ɯ�����A�	/Od��Rp�j�V� �L[;?�/�?���P0eюЉ�5D��T�nS�t�Zr���-(���*Q?_���&"j���seB�^Z��;%c}�T�]�քD�>�� �F�i��u�6��i(�;���ˠ�Θ�d(�脏�Qc9L
���v0h���Y��j%�ed�)�@/[�5����s�D_�+�2�+�p���{h#��|�`�ɠ�!P�>��>{������V�M v ކ��_��2!�}�2�Af��ؕ]ǋ<��ֱ�`ƫ�����>��(�!��#`�֏>��5:��:	�xyC�rV�%3�����	��C�6��������O'&�vg��/|�#�R���⁴~���\��G˛k�NO�>)�s?eJ��[I�yZF�N��N>C�a�\k�d�F6�ӏ�D�*1V��L�I	�''`:S��V�d�(\��� �M�EF��&����$Ywo[`��k΍�4`]�4c ���U����n#jn �ɬ���}t��	n�<��������X��dF����/�GͯObW��lA�B	B2��-+�?��?����y}AK9,��� 0���EӒșQ��vg"x���Wf$�����.����|py;� cS�z���h�,�.>���c2.�������B^�R����d1�
Ę�
�v+#��q���M#����w�$?<�r�<�3�:ҕ������Bnbb���m�]B��%��0�-4G��GW�9h��0���j35��A��'{A�,�/'+�o?� β#U/Ct��D��m�'Ln�8�q�N�9�������g|�ϝ����o����P�+�JC�4�A��w�U �oQ�	VZ��	@�+�����j�01��lF�7-��N�S_0!_�"ޚ��:we��N�
P;�]�.�7UfB�Qr$_ �cc<K�"�j#@��V1���mI���]	�
Zܴ��:ؤ^*�� ��6��+�;�]vE�����wAR�D:Z*"�m��m��[��܅oT�'��t=�J#�MI�����N�m@Z��4$��zr�G�D�@����f����@d/
A��7k���9�붌ڇ�V����@���8��i#��j����Z*$����ѻ�^�}-R��8�o�q�3ZV* �s�����Q=�.��	�gO���Y�s`�	��9�2٠�h���ϏH&��S%�d�����_�k]��@^��9j�ń �%ClA���8��a�D���Ӏ&m(�#Ehȴ}2-|�Yo���>��w�����/`D[��g�u�~#�Cp���2V�S?�j5�$��Y��O@����U�b=�I�^���������7$&�Z�̥��j�"�:dm��]܀bB9y`��:CE�j��S�m�JZ��,SBG�:^�̿cq�H7�xt��:�����`e���*Ē��]6��O��蓒����HyI����s�������$E3���,7��,�y��M� b]E��&C@�dz���t0    7QV��ƚ�_
3:vMx�@@v6�!P��y%��u��%]��  s�)��^�{�F�Uȍ����R�����f��-��$_�vy^�G3��$}�{�<��6֠���Wv��W! a*�\�4 �H�P���>��"v�O_E7cT���?ܖ~�h�¢��
|�:�L��"1�.Z[�xZ(ke����x烂E$C��H_��L�N}T/ ���G�BJ�/�{�{�����¢���o1�өz"����ML n��T-c@m7^��\�{�*�����w���x���"Μ��������s|�*D0����kO���Ӹ�!�ԥ�Mv�g�'�g��.hv��:VԕIiz���,�����S�<P��oT"aN���U���>n�"a���q�ދ�k�NU$����guDҼqe�A����� ��ڂ;��q�v��.���@���0�1H4�f�ݼk�4
��:��}�<��t�D n��:���di�jy���>R+?���->D�ۿb���8�hdae�u��Z1�h�}�Fܫ *-�j�~�t�?�z$k0��I��KO�q�_��}@B��0��͊��fyԢs����)[��0K�R��:xD�nR�D�
ԏ���y�����|-�U+U=�@�Ҁ�WWEk�?�\Q-4MW�����b2��Cؼ��<=������������F�d��(�%b��~#��2�ۭ�SX���A!��a���h�F~ٹ�A�j�+���ڔ�r�I�X������A@b�����
:x/��ݕ9�*&�Ј��a�E]�w�&@Ȣ�=-�D� )���� ��G�@E6�.�Q�@��T��>��&�Z���\' e䄥J�D�8����<h���1�1cK,��U~x��v�b	k�3�'C�C[8�/��YF��O�-�f�1�ԇ�3tʓ���^NS}o�Ft�]j�Q#o@�9�(�V~N��{����(I;YTO����}eC�j��6E�O��B��C�-�h/����.N�a�*C�&P�01z@�I��H��	A{���xe�sJ�s���L, 7���!��G�Sd���~e#�4���|���t�k�$�Ҏ��d�2h��Kn-��Ӳ�(Q��h}�zi��}�_���K4���:�6 ~�=�0#�����՜ ��������l���k���~��in=�y���+���F�
<I{qV�3���ae�΅΁�����t5Q,�U�"�:�Ƃ�X|#(�����?�(��/�#�Z��:=lt���:��=�:�95���E�ȳ��bD�f�}f���u�l�?�(4&՟�s#�d��:Hm$��ӸVw�@�n��ĹHHd ���
���P4��ɽ�L�$��̢�sd�q��I&`˥����#`�?��[O��{�GRr�|�mh��G&E~�ܬP2B��^��E�����������������|�0���^�ϭ�Z��@[���FY3>�E��h��i��~��;xY�}eB�e �DϘ�G����듯@ N�QK��q���&��y�Mx�"�E�(tq���a�	���:���6���C�7���	�SKN��s
t�Kj�o�o#�(�D>Jq���L�k�~� �pR�2#�D'I^-��*� ��T~Qo�&�a�څb��;v}tx�����.��sv�&]�ᡸa�U�**ϪV㫐�+�i1Ҏ7�/[�_C���ML�����HH�k�E����fdг�a���A�	91^�ho1d��Jwi��5�棤O�HFڴ�88�j��R�f��n�]�`�!���!P�V@�A��2�je�0h�5�$%|ҍ���YK%1��A|&�J���X�]h񤡎u�����p;�����AH&5i�����3��F�q�"�K�d�@/9H`,�QE����m0	�hw���+XO%�9~4U��2��fz�d��Q팢�W��B�	�9ݡ��a��$O�-2J�@ò����\�e�n����
�Ȳ�[[�cv�܈�|X-�'9�i�?�����	e��N��+>-FH�S�A��}��LZ���H�G[��z#��.qS���*�˝m�2�ʕ�$��i�6d
6N�G�4���i�5��h>�
ݗ~��@�F�n�}��y�K���;��:O�z*z��n��BFt����d��#�i���
ҽ�*vƠ�%Z;{.Ӱ���Uܙ�^ܑQd-D&ql���E������mLԆ��V�2��R��g;�A�~��`|�ȣ�̅]�����L"e��R<Y}L1.j=�R#��V16`�xk�������n �0��ʹ�G�I��Q�V'd�,7�9k����^�6k�;���$p���m7نl�T�T�����Y��8q�/�l��i���>�3�g?���׍y�E��p6����;\���bp�7��N���Y�Ν��np3.Ĺ�pƟ܅N�l~ӿ���nƟ��l8L��샘�w1<w�g f��t�;tI��+体���3�v�ua�v�7z�偸T�F�܈ ��caU��.��3�g��F��%��
�A���N����fW�N���[���5[���V�u��p�]cW��ñ���zp�����E<��cR�p�pi�Lm��ƢV����G�W���À��XL���ir�r�E��]P\�]��9�F���s��-5���!75C3�.٠����=yXΟ�&����-oiߌL	y�>}�%od���g��X��~�H.3VRؔF��kx.o�Y9���S�<j�.�|�s�>?��� �Wrio\Z�'���ɡE�}T'E�&�
���b,���_���i�χ72�~*�s�q���&؛@�k�Ԑ�}�� 7t��Nq�DOx�o�9�g�!gu��Ȳ0g"�z�L ����d��M���i�/�
=U���;��s��ͭE��}�c��l���l��M��H�h%�%�M��>/�ȼ�E`��f��O�V���|FT��&�TO̷�����㛶ȕ��#W{/2+��&c�̦�e�C&S彔�a`�����x@]��t���/rx�v��>��ʤCnP��bd1�Jl-�b��N-��Bmw62R�&����s�z#L<�7��ѡ=
���++2�Ҝ!�c���6���jw@���ϰ�~rZf��T\ݎn'����3���e��3p�`|;u\z?��4�z�tD��fc�{o~��w���Dݧ�I:�����?Bآ�:x�x�(\�gR/s���A��ҡ.KN�j .Nfγ>L�ސ�&��|1�G΂�K��E� �g�n��H�~�G�F�h��;��U�5����(�E��s����Q�����`��8���C�dB��q,b����N�Vv{� �2[��U�� �/��/m�
� �Z��y
�r�C�u�X�/ǄPE̻�y�Ood>ex<R$�gd�C�g�3�ω�.����v�Q�	�SJ�M ��T� ���������2|�m|݀�<�ࠋŹ�겹ʉ���1 k�uҞL2)���@8K]��Ψ#1 ���'��6�PPJyi�I+Ci�+e�4d�fd5��v)�p6͹�,	�u�#s ���
0Uk��pY��]2?���ߞ���ޭ����V��Z��iN�b�X����YEJ�)Z����s��ϫ�x�=���e`�lM��ng����l�C^�b��XE�@"I��b���ri�w�"����Ϝ���ܓ��/\?]� <���
�=��h�
�p�S�G��h�'<.ȥA���`���,kX}�V)OҦ�ȃB��Og���~�B��Z�}�)&�a�Չ0(��"���S�����q6���2�m��.#��	)J�)�H�)�Em&Ӏ;9��;F�'�\�����kw�/��?��?�����?������ �w������?�����[pvh�kAڮP����o�5�ٷ]���-��R�_i�7�z��|C�a�1.�W�K\��B���7��r�d�ˢ�y����Z��`��n �K�D���N�nm���PM��%x��
�#��0��:��@��ӥuf�OJo�$p��E�Bvg�[Dy\�I���,�7*�r"    :h�Xu�����uOL/�
;�+��K,�fZh�CR�Ź�!@05�<��`�P��dȤ�����ݓ����S"'icĂ[��D�PW9�Yv����.������i}r�Z�Y���^�ϺtҌNm]�H���2�}�h�{�͏edS{�5�Ӭ�q�HK����hi���rI�R|��G�Ȁ� �}c��#�L�ʚ�! �Ȍ� �[|�
�[��i8#6��/���bei�=��L�(f�Mqt��VXZ��8~��o�ݭ�A���7��f�d��M�-��k�Q���bW���~�~}xޅlR�{�*���n6���U�����B=i��ގ�OqIQ�$(�᳔4!9zNL(n�q��		��h�#�Fk�^�pe1~e�ʥ,]2'��*�"����f�����^#k�zC�*� ��uEͮ����2cCYɭ}��(PO���-�Z��D�	�D��Y̝J��I�uƆh���lX�e������5�����������0[��!���	�m����<w�v車fyj��T�k#|NPO_�y�vΓ��RB��Y�7� 7�����Z*$W�����m3��E9N�B�}  HL�5Y�g����)�+���c뱃n6�m� +?��;�;d��6���!<��f�����i�M�9d����^�>�K���Λ�#�:i��wܱ���ط�nHm�7Q��������ؔ�3Hrе��GTf�����.ܽL��,��V�|�]����HI��4�)]�q�϶l�w������EM���1]�.�FO���2tO��o�?�n���#�a��L�b�?g�9+�:6��z�O���E֜�f�v�6P�Άq�*qfѭ�z�N��՝�>)ƹ��9:~�:��w0�;��g��|[|��'~���r0�Y����}��H�t��h1�3��hputL/�7#g�iw���pt;&�u4����B�
w2���`>���ng�b0%Mo6��~��B�įlpx�)$i@;_=�ҿ�(YV߻�$�-�,�+�i���c�I�%��7�1d[�h��$�pJ�z�1�ť%��MH�èب��U�upOVDh3U�p�d��ЍT��]�z�����3k�-��:`W}9]���Hg�̒�ڹot��Y,��ԫ�_'/�\����o`nӥ˲C{�ji�W��At[[�l�$})xT�̧��O2�^̊��$;�o�}zz�{:��[�h�Єr�
��8zI�ϝ��H/B�5��� M�YC���,K����B3�IA����C6q��p�>c�ő���&�i��7�'���;������Ym������7s?��-=jLm��y�Dk�M�=뙫�\8�L��/B�nx����G3�9��L�!��g׺9n���cQd���~`�D4ٴq��z엦S9#���s�Z�V��i�HU��`K��8�Z<��&zD�b	�)��F�,��v�1�<�#�kN"Q�J���6bЫW&i�k�a�z�Ê�^*���|%r���g2B�I�-���\�t3�tH+��j-�����G&�> �*H���$�~*u�F�k��F�j�,Ѝ�%�V�N�r�!�ݳ>��}^��yl����W�V�~�j<E���{�똻�:���2?���3��v�̵�&X��k��/MU��[��k���G�j�Z
W%)$ �)Y!#��~������f>A���Z_��w\�aՔa����Xfȸ���1Z��X�'G�^8[β�C�#%����`���m�L���P�q�����E���8�l�O6��Er��ni/X�$o�f�}4(.�J"�n�%��H)�'W��J��"H{�Fk8��=�hV.�W$��	T��J�G��U� A��V�� �s�q�e����+��L�(؋K�q���A��!m���+��'Hj�TR��u�����.g�f�ɱ�W�w&
@r��S W���,"8��q��leo���+��Xn]t�U�=r�Wl������ �� O�U����-��DIwrM��FJ(�&���.�7$�<��s�y%�@���Q{4i��E���Z>�����;yjw^��9>y%-�@|�0.�G����d��&-�/ʈ�L��F-��ÆkC/�̓�JX����+�����\�6�GN���\:C�R����&����|r�D��p$>9�KAO����Q������h�,�����oH�|�0�����5����i> �f/�ԑ'�X�6�;q;�:��T9�������Zm��|K����п�Zn�����Qw��j��~�Zn���g^��A���t��uupf((7�5?�RE"�sBn� x�ȸ�k�[*S�a�\Xd����6�eP��|]��m�%�!��z�#I �lp*�V�~ӵ�捻[�XD�#��.��w��H�ͳ�:���OJ<2�z#��E���|G���:Ht`q��^��R~y{[4�o]5��͂�P���7.�\\��L ݑ[���.9$N��sj3���ڮF���^�O8��H���ΙAr��$ng|3�����?��Lh6Wо�$
ǓK�e��2t�S��lEτ�z�^$�=��$�q
�8�oT����tW;p������k?V$��i��iA�&&I��<��n�D�<�����#���r��4�$�����u�2i3��9i�A�l���1�)��h�t�4���,wĭ�
U��M���α���� ����+���.R���P׭�Nߴ����}���,F���]�#Ê���7o��^9NL�4�|ߒ���7>��lQ�N�P%[��ZGoZ�,-�O�2 ke^�ȕ��q��a��N�V�MK�΍�$o��=*�u�n'��X����>X��4ZIS�	 ��)3<��v�:~Ӳ�:���,���fQ!��K��2u��p���[����b���m^�]��7-90�> ���PD�=V���Ҝ#f�W���8%<$�A��Bpx!I1�ZI5����'��x]ڱ]Э7-�"4F'��#���XC��IM�F�U�j�惋1�d(.�>�a��!2���5��J�N�3�.n�C�̯H,3q�ñ�.Ù+ܡ{�l�$��M0�|���͈�v;q觎�ѽ�`�� @��|MO����]j\"����^e�إm|�S���D����S�_�i�Hk�4jT�U��f���ۓE�rfX9�MVɈ"�K-Җ6� �U1�G4�&]ԒJ?#�Z L*ŕJhL�&μͦ��u߲8m^zY�^�s9������&����67n�I�f���]+���m�?`��^�ۼ; �lw1�	�Ƭ�p/\Ԉ�C��Se�ҖAs���:y{��0�J������&�F�{���r�sQi��=�s4Z*��ʳ�g�fI������)���t�n
��N��K�X���ʌ,�4�)�Wki��䮼D����P+��_Z�E��8��);�ё](���k�-be1.>`�T>�ڍ�7(LgO�*��3�KƌrG���F���_�+��'�lf�"�$P�ex,�*yR*�n�ZS��~1�� �w�cV����ڗE�z���[x�z&��F�O]\TԪ!*@b�nłt��p&��K���>�C����E� �i�F�W�LI,�Nm���̜���S�o4pW����)��|�\a���q@�?R�l���SXfC ݇&�4�G�P��g�6W�5Z57��>��D_�����p�\�����c�w�L�|�X�X(lцB�����\WX֪F�����sFG��-m�v������gl#˺A$<���lwެ�r��	9R7���A� �ӊA�q�=�\p9��1;��q6)��3�ey�\!M+���V�V�j�@�� x����ʳ�g��gH��v��BO2|Yx -+�ǵ[���v�i��y���
�L���x��O�،�p��j�p;o��Y��)���ѕQ��w��7+���W�4_X:}p�mB2�+J��SLS�c*LI����'��neqC*CJL"mr��,�t��1��g��ErB��fE^)"�f"��Z�G ��Zn��WPO|0L�����^_�<�s��{6��    j�v�߬�gP��T�c��*���f�%0�`�~�P&+u���~���4��a�')�/�?�R��✵��a����	`��t�Z섀�:#�<��>W �fd]2�i�p� >(�^�0!�4��aw�Y�?װ�.��Y�FۺhuĹ^�� ��~��6��+�=�8#��NFI�)n��,>�Ȅ6�O��:T
��I�{�<��R�0)�''��ױȸ,n/'���mK���Q��KYN�P2�vV����Q+ >"]+�=𑁲QfR��nW��O��)������5u�d�[�n�L1G���ФC`��z)���y?�8��f��Pc�B�7��$.�ױF�L�+!�F�V����pQN�>�����3u�s}���e+#�50:����v�T=�i�j/n]�:�y\e�ʹ]��x���.�~�owb�*;�%jї�����O��;)Z���V�+&�4��%�ý�-t��`i�V���t�6��9g=�����$�$����Y���+��$ ��'gt����N�ڥob�ɻ&�.��!���k���σ7<�Ƌ�:U�i�8��x{Y�˹�6�IID�z��	?ˀ���זH'�-�twN�g�۝-���a�y$�- �=��Zߩ�� ��zm���W<}ܕ���
�30�(���O��;Q�n�.O1���?��ٸ��~��^��X�^�t���O���=�-.OC��}퐠���t�1u0��<?]��a�]�#ǵ2���H$�]��aN$A(��H=^s��,�E+��G�GҩϊNWd�7y_����=�7�<{n�v��脉V1�&�B"[����
a����,%/�٢����3���f���%�؏�m��m�K`�ab�Q؎
x�����+��*���}՟ى��?�)���_�����@�1�ೱ�v�?7����	��t
�%�+�����S�U&�&�m���.g"7��7��T����5�X���of�$΀U~��j�n�7�ZA��)����{�%(f���0I�9�9"�$�@�\W���'��\��Or�ƼHr�Z��C��S�A8����8g�32-��7E��I�{��	z4{sވ�����^&Ԟ�Ɲ��OEt�|X�Zc?�3!Q����8�s�
b�:9i�ƽ�q��~/� L���yr�r#9��0��đ���O�/��=s�H�U��^n{m��lj���k�/hbh��푢���**�REM������8��k�4�����Qʪ9�D��q�G&(���Ȥ; Q�h�cE�MzhѴ�|F�a��T�����I���Z�K�8��F���X���Tz��hM}���&�-z�1Ħ��v^�����&����me_��	��:�	���8��ǍsW��6���	�V���T_���f��S4&�Hgd*p���dT`��"Ƣ[R3= (x�J�[���l�^@���'i���(N�&�Bk���q�%� XH�$�g�@�����}3xqM|���͠V.��Sq֯�����g�D.����ao2�P�ON���k����J�/�ƍ����E6�t�G��p<�䠚`rz��V_\���W�V�C1
d�����V�D�hd������{�.t����z}qM|_�_�z�E�t��[zyvN�E񕏜 ��bBK\�k�ȳ� �m6�B>�]�n38g��I�nw�!#��l6��*#��+Gl,���g��F�2�qDz08wh7Y���DI��r��\Uds��S�_�㲪�.a.@��O~��?��p��?��X�8�i�U��6��b�vP;C�ZDmN[��sC�7=���h5ۭv��=���8�V>�]�hi�H\�����y{�~�2�}(+LN;��+3$E{p��� ��j�ӹ��+���N�d�Ł���uD�C ���`0(�y�'���}�ա!.ݩh���b؛T��u��<2��Ʉ�4Z���m�BPMv��������' �\���uw~��Nq�fOF�qp��yJV:�1���2�i��H�Z��xQ��n�nw�������R5ﮁ�wq5��@�\�����ʙ����Nf���ǂ^���p�
g����~1s��ObXg1�� �>I����Qʴ�	�n��,���aO��cl�<ϐ��3ADm�|>^�m���j���nF_�ob0�����)#���;��W�pd�$��^,4��]8�K���+p�F4�P��cD�0V�ؐ��Ɂ �g�JQ�[iA�Y��1�vP��s�/&
����V3��0��^������!̈́�&�N�'��@�M�b�Ef�=��O�[�?ϥGK����c��%'f(oD��[�c��
؏����H��#=,���IP��a. ��C����i�=����p����km�k��<@ZX�jKR�z�ݤΪƇ��{�|�?G̥Iϩ��������S/��6_FGv Z����3�t��Φ�v�D˔>K�k��2�H��m򣿀*j#pk��-���~пЀ����%Aղ� ?#;��j���>2�I1�+[7Q$?"�ڐ�略@��,I;&��¸�td:r.�1G��<t�Rl�}(��Q�}���A�aU�+T?�D�1=7A@��i�
���C�3��X�mKJ��d�!y���ćy��*ĉU�Oއ�/|��J�3�d��[V�q���'8��ӂqrN�s�d�K��`t+(�@�->�]y�{�y�'<N�'��?�m�I����v�&���]�@.͏�9�mkT���t�1���]���[C7�?��6�އ���;�$��>�c�7:@����Ro��j�"����k�Xʊ� #���՚e ������A�J��h��Elep��|i;���?���RӤ�(Ji��d���2�Ulh\�x����ɖ-n��Z�Ĵ�#ƕ�1I> s��lP������&��֛7/5p�&�qƅ��p�����ب`�6�vR���ʍ	���ʇ�$P��D���y_f������h�'j�}6����b��`��>HE�LC���&>&[sZҡu��*C���n#�{�h�����{6-���B��*�����sy;=2�˥�6d�G�;�8X�Wi�fh�(���3lwk��YZ]2E^���A�.�T�D|����"B����[^�S>t�����Z�L�����e�IB��y�)fFuZ�IHn[U�6���z6Q��ӝ=���y��=G:d�.��p�]�K��V84Q�tQ|[��k� LF������sm�n�J�iᨗU��dtqKw��G4����#k���QI���oR4��00]���~�դFf�]z����\.��4�T�$��e�#&��^/�&
Aƅ�b���k��U
*�sȐ��=�W�V�C�Zf ��zTl�^�A�
���
`�,2% |M��l�%�/=�|�b:Ҁ�GxX�\2@��m"��"r�ެm�%�����*�E�dx;�s/.Hc��/+�iL��r�d�#2(�48�}ܨ������L/��pݙX&���������v������v*F�+^�b4�����;�x4����!n�4 n?c�t�="�.�#%�$ڽ�e�ɀ�й������>�����L8��̭��[{�@g���*��Գ�����476 �‡�$;�o�}����i��=_�媮�o5������}��o �����aI����H�<:�w%�{�D�;�9X]s�B]k�N�MjQ�+�{�|%�-\	4�Q��)�I����z&Z�;���(%d�C~Yd}�^I�+L}�����C�>.��%�O�O:A�i���[x0,+�$� CN�ʏۯD �!�/�1�q�5�8>"��OC����bi����3Ȓc�v �ݔ�����y%Ҩ��O�x���)�B��7��3��p���k?���4	_�:I�yq��n�V{u+�A��Ȁ@�ũʊ�cM_�D��.������'��\weu+@��=0�B(���pS0M��,�+w�l�w�^��tO//�`3��ޥ�v���O����*�8QV
���-�z1s��-L��    �������ybi�g� |��)����L|	�z���=ƳM�Κ���2B�"8}s"���`펳�r��&���=�ڄ=Oͣ7'n�2b�u�O�ڜ��K�n���0^�C��:�[��n��b~Ѣ���vt;`Øܡ��|>��O��7O��3�'�$�pÁpzÂ�ޢ����B3����A�H)9�K'`���9~!mk�Vul��/�U}�b�����l��F�މw4�d��f�e4o"�]N��qmr*�<�{��@�"�J����y}��x��d�r����Ud�<�Ъk�:k�'������N̜�b茩��D��~�V̇7s1w�H���g7�B\&É���x<8_�L>!'9�]��i�/6�6.��(���i�!�W�Cj�4(��:��χ#���{�k�$0��hsއ�w���'D�7`�P��c�W?/C�X���r�;�A�`�`���BmB�����|��_둓t�'tB",�F6�B��<?��kZ��b�&���+�u�>��s8��!�n�,�3wc�"ƛ\%�zi��>ȯr��ҵ
ĸ�p�h���g�H��ʃ�&i��k�L7���1�z*��)�aHޗ*��퇌�>��ԣ�����|�8�����D1���s�X�3��"����zHA!�`Ef6�F΢��d^��wDo>(J�����=h��n����7��3G���p��������1�ߌ��Ѕ-��0���썸� �߰}�������K��\�[]$�d�ew�*r�h��
`8�	��* ���'��,w ��i=�R~ܔ�����
u8W('�	򲲸J��rfO����^�{��e#��Vp����T�V�}�_�(�O���p���<�2��Vz3|��r*���D�^!3��a�j�M���o*���0���#��ܢ��w�t�p�T���N�O��,s�߸ll�(�%t���&� $�������" w�b���f&9��d��@ܩ8)�E\�q�8��&�R����289Q�e���{��������O]�>�|�)��#+��k]0r������4u&��������ę�s��j8_Sqw5 ��r0�Y|��.ӿ�I�Y\�1#�-��8�q�6Ԩ���p*����3��ˊ�ﴷ�0�S��l��(�BMJ��Wh��O��8�<�����٘"B��b�����L�7b�?�
I�ҏ�b\x��J�f�y�<E!�C�~*�l�A>�0��E���}����x&,˱Z�o@�w�����\6;ц�5����ݬns�:�m���@����l^Z� ��%�q��O2�_�(ah\ ��q6�I!ӈ^�eC��x���z^&_�}��p��b;Ch�����?���.0��d�<P���+�����I��g(F/h�~.d��o@|C���Y���HJHi�"�7,�pM��[�C��g?Z#�K��vIW{)��H��d�G�u�O�X���db�����W.��B����~�6��z�����i��VP�b�v@��}�+���v�͢2��[�v���4	4�<݇��ɪ$:_�
<��˩�z����,��V;}��Mb�Z�L�zx�� K���K_L��gfNǙLDy���v�������P�ś�*2�r�d`i)�������~�A���D��:��+�]�Y��&:I�T��鶻oA"�8K��Q)M�{�*�����I%-��G2K>m٠�MB6��E��/��>=�@��4�Y��}򆝝[�Ag�S ���J�e}�TEV�ޓ{:c�im�����
����oXBUw�Xo����������T�Hތŵ\mP��D�d9�:GoXP�T���L'Mj�`S�F-�`j��4J�D$%���փu^�voXJ�$�Qꋱ|Hm"Pn��Ø�2f�:����+�@�h��Dr.�̈�ܧd)Ѧ��99���v�߰ 3�@tPC�$սlAfd�ȑ��L��VJS���d�g��T�Z>h+�k�%��7`MC
�WޭG�q��	zf�k6��ox  �Ԗ�j��a���2��="!���Ɩ�zŗ�v��|�4w,:�t��Ixӂ�o �D�U����k�T�̑�^�7Ox[a�b���OF�Q|�H�<ri�J�K ɷ�;�IR�מ���#�"?k��z�I���:�7=?9��%��|vS���2ˡQ�QY�F��P���i+��#�̃~�����ƕ��K-��}�2��VE�����g�U\���D�����K����X��8���3R��bf�t�i��t�:����g�'E���
������s�fh(S�<�h#h\�d	Գk�&�ڠ>br�+Qb��^fg��IV+&�P���UK��!�J�$ط�ݓ b/�@:�o�cd�/�G��Gj	��Ȥ�C��d˝���\i�LP_��ݣ7��Y��p r�c�� ��,ZSf��0[������>lq�e��Pi,'!Lsa����B�9��٣%UhYI�I�(�ʨg�q�m2��X>��V*Ǜ���G��=�F��la����f�!����̖gy@P�Eu�d�uvOl���F@�֡���2Eˉ�қ-h~�=���;u[�j���7О���e�tf�;���Y�a���
|:aL6R�t���6<�`c�9њo �!�7t�y(p�d5�h#5}�ʑ��2��6�ϔ���[1����-��0�d����g��[�u~����6�{m@�]�?H�Xn�9J+c�ɣfo�߽�躵~�Im�U�2#�e�)�I�xT���!���g�^��t�a����Dk���ސ�����
O�ɬ����::K�L[K&d]�SX�aVjI�����@�/hY�����A�VO����2R�oM�jG��64�.d8�5���:��o�P����a�ݢ���$�������=y�Ⳏ'��V�ҵ-���8r��'Q���J�]���w��ϘԄ�������߃�|;���i����U�J(�}Y���O�i6R>{hB����z/F�����'1R;��}�Q�19h�B{l5�ϲ!�ǰ�5�����/�hz�_�#�n�b3��Q���ݔO�����˗a�W^��^ynY�S:Mʞ�P��¹X��@Hr���RO�%��I���`��G�5��w4W�߇�Q8�Kej�M�*���;W,�*Zg��::�0���YD�Zd�� �"'jI��fCMӱޱcw�˩�=-�����@��$�)-N2kzi�U����_�xN�/_�}�]����~�ĩt�>�ru^~7k�V��	�Zi���Fs(ǐ;��ZU�s1�~�3��+�\�'�xW	P qN�p�-
q����ge��ɂd�a��23Vm�
�!r�-�a������*A� P+�� �`ɑ,t*�_�U��/dN�k����
���7-�/:�B1����3��^��W�J�����eKS� �t}R�q��ܢT��P�K:���aK�=m��q�
sr�>0�``j�I����$�]\��:�hq�B��q6a���)Y|����3夏
��ͅ�:��9}z1����f2�q����8}�9)�اL=�`3Θ�B>Dp�\Kp���a��z#�C����j+���k��<}�_0�t�i2�A�w~��:��om����^�E"��Sv*���G�����Y�2ڐF��c�;`b�2,NR8�%���;�⠑ӸY��ƻ���OZ��mqMZ� �d0��eQN��O��K�HԱ���>g��sM���>��G�8>�7����Q�{J�X�V��v�.��d]pw�S��d�s�]���8��tIMC���r4��ֻ�Ɇ%�d� �a��<V��>� X�t�5J�������:���R�P���&�f��?�WG]Q�}*>�3��1��%�>������iN�Gp��ʆ���Uv6Y]��ux�� _'S:������U;��y~u��6�������K��nSi�(L��0�w���o��ۗ�}�b��D�D�2$\%�Qt.A�U%9�x�P    .�
#����D�6�j�^��������5�ы�J���|�l�%��,�co�;��&I���;v�z:�52A�������N��?�'QѤ_
'�.�4�*D�h��ӗ�[���4N";YCd�o�������REI�=9:z�}�+�?	���[ W@,�bL�GI���C�����DV�\��|uirm�Ph�c���K�O�k{�=���E)�e ���Զ���U.,��f9D��Q�v������u$>qP���/�52O@Q��.�G�$|�22��	��ήM�*��4G�Jd�61�^ZGBG6ޭ�*�<!`!��و��%�+�a���bJ _���?��.�G�c�!v����˛J{���Ԟ��d0�]��#9�@�'nVW�̼~ k��������g#�Jg������*��UP"\��%���զH�9��$Rw��"Nu@7���$<�6u�[�������{:�<���'���A�ܪX���q�4��|�&� ��Mw���Ŷ��@�����u�8�M�:дIG�Z+�@;��J�ux,?���]�gc�"����%�!#�}'e���L�=˺�U*��ηL�n�^��If��(��JDf	���H�J*�����y�oq�-q�2���u�	�Ě�9���/4���2}���M5����!�R��ԛt���@v���S�#�g��Y���fP��[<.'�u\.e�i@[����`��H����lDψ*���k���L��2*�=mƖ��c�ǬG��%\ELKq_��PW���xx�wċ��}�dQXƽyf4�^��f�E1^9�"�+5)�k:�p��-����	�{Rj#_ƹ���Xy��%9����Sub�Thaf#PKdT/xlN��*9 �Z�O�<Q��KR��da�&Zw���v@��;li򥑲�@j�s��o����f
{Ԏa��u��d �§��H&��п�T�L��O��eh��{�l��N��(�*�`)������4����w&�';kjF0���l��v\���Q�O�=zOJ8PMD�¹)��Nh#z�}��Ofe�zƨ�ܤڅ�G�?w��4گ��=RUV��+G��g��S�d�61dm�N���1l�n�͇F�M��`�&=���O�����Q#�bI����u�쉰b:��u�q��`/�d�@����{��F�%]p��;���H=YZ���aP��\��bD8;R1W���f3L/�1�`0���\̢q���8�d�3��������dJJ
)J|�������}_�88����IQ�K�WM4�0�D�]�5����k�bH�������,
���+��"(j��8����OА[��;�r_z��(r[���O[�Qy|8zj�JE�^2�p��J�{n����$�p+}҈}D=�53��ι@(A����C��ɏ��?{pPqLz�0V�c|�P;����s
�4�����D�)�낃\�oU���Rr�#9�D_I_��ϙg�@~�������M+sZ��tZ�%i\bP���R逴���'T?��jʙ� %i�̆%��Fdo�+�z�ˏw�YKS`<�^l��UQ;<8�?��,�b����Aߪw�g��W��	�`"����'4	S�4�EI�?\|��Ͼ�R;����ᗟU�?�n=*^�kڹ��Q�eA�*����K��D{�<2�/��DrX�f�"�9�#t��%�K����L�@{�/����{B�t�o�\�G�o�>�N����u�qN�qXS��<֥���.h% <��<�d\8	{�9QZΥ�[y�
���m}�
�W����_B��� B)�M�\|c�g f�0�S�єW����+zV ���鰃�$��'Fx�:/`hy_��Zr�N�sr �bw���П�3*ĝ����*y/4����PA[K�ޅ�f��SE�0�Ĭ���b-�@?�Q�A3��{�?�_Y>#C�3��)��cQ;xGµ>��(�X�O�"[k�׭lE����"�8w�q�_�f��10A7��!BeWq�	z՝v���jw� ��m=}�賒7Skg�1g�����4��j�/q��H���K�E��8cGW�����!.Ǥ�#�R4#%W���r��+&�R�O�P莂
(����{�������T{����:�a4w$�څ�ΪAH�Q�_�&�d.���#z�f������zKҎ۪p�#뗊D�d|b1�_���4�t�N��Iu��	�:B�m_3��%cK�����b����n�깑~
	:�|�P���-	t`��͛��v+�]ى
%J`�d30�9����am'���j+��ND[u:�*�����NB�W����'��=�a'GbH;#���s�L�Mۙ8b��՜����4�y��������[�+��H:��Ǌ\�%��*>����][������q}��!��a�r�s9�d�ኜ��U���,�>�'胲��N��X[C�^F��!�Ok�¡� ��6�����U
g�j�\�O��� �ۙw�hGȰ�x�gT����Wn d��O��*�0Ċ+���W3�&����(�~��K��*LI���� V��~ .�J.Q.��3+)V@͊�>�1x�]�R�����?�?�5���z��g�F��CX���Cק  ��"=�M��� aN!�;�?�]̤�s#a-h����+q��\�Z���b�2%�5�:�Z�-J��j+�1�M�o���F��7��Dq������E��s=�����.�9�}T{5�h�<1������l�2}B2,WqI��Oߑm\�ۣz�S.
�`tJ�0�i����S��`�Q`�ڷ�&�`��m�=|&���FƆ�쭭�^s�e,9�tv.���V܅hP�g��Cs�W���Bg12�Rg!���ET�8�~��U���_��/>>������X�G���_�П�ǎ�O�t��.�kv�/��� !�"�s>ROp|QN����T��AE�$���.�|:������N-wj����b'��(aiVom�عC!�d>\�^ۯ=�gGG;U۩��R�g��M���_��"|xt�S����65kJ?�WW���a�ΎNv:�өߦSC0�I�P����'v���Nw:�ӱ�x<_6D_wv��c��j�T�I�x��[�O�����͖~�8Y���(`��4��&�A�Z�v�@��Cv7q��C�RJA�c�"��i�Ns�9�s"@i��Nܶ��I"�����:�;%�)�oR��f�FC|	��B]V,CՄ�=�[�q�a�q��Wꞩ��a�g���3�1ܔ
'j�����Z�P��q[l��*���
���c[�z��p�cҷ.�����Jr�@����a��B��MH�
��-3��N���n��h��?�[���A��*��È��z����@��l����Jo8t���<�ӛK���-���
�w�bй�gڻ b����׿���k}$�=�w�7cg������ͰyC���N�(�+~�L�M[�����
d�ba�zF?��ПH���������W�b�ؒ؎��#�����'�.���-�����f>ĕ���4���rN/I��Niq�S�����gϠ�5�-����X��2��סg��t�=-#��l�H��^��+M�A}/Ƀ���Zn��;��aoF�7SЮN��{�ވ�7�w����3뻖T���:�R�r��1�>�av���q;L�
�Vg<���ѝ#nFӛ>M�֙�P�:��ZF�2�/n�'�����ԑ�4�"U���K��`���DjQߦU��DGQl�<Seð\�!�8���FG'V�����_WŻ���{r��j5���Z�'�D�+�~���H^��r����-#��2�0������Y����&T��Uzt��K�QZBZ�8;9ة��W��ҥ�R��Q�O3�zo��ɐ��>(��{i��L�MVC�\M�O��X=A�d�E=UK�����>ä<0Y(��<�5�fokV�j;�z��e��5;�^Lq����j�7N    � ���,���F����
�
��h��W4"0"}���͹XC��!/��x	�o�\{~�>#٢�b�ta���׀{4�ބk�~7c��<Z)��$�J�2���;���i"1W[��K��r�[|�\j�B�φ&8]T��'G/v�%� ��
�ծ�\�N�g�j�S��������>�}��&C��`n櫍p<�g/n�N�_�,��v�.}4~����N(S����Ƕ�b�/�D\U�$v�Jb'P�g@�)a�H��V+j!ON^���敟S�HtI�r��$K"�8�d^*Yq�������H���X�^H���"\Wb�p�b�06q2��q�$�t�?�]Q���9��E[\E����ً�a�2�k���T���&I�B`��I0u}���������0�wʅ��^����:�$��Q�����YGp���5��b��8�ܜr�x����c+Ǎ��$���B65(#�h�C�嘜�v
��BO��-�'Z�I���I�io/���IfDJ�)>�#����m�*�W;��꓿j�<�J3��>�\5���tD��m��i���}ty�ݺ1�z>�~�E�Wfn�2N�4���G&�ǖ�a^������[��N)��X�>Y�k�HxqzZ���wӦIrN�R��^���hV�5�ݏ�����?�������_���'��2ܟ�׽g���
}�����ɠ؝�3h��(�!����¸�����5H��>s����Đ����M�	Ʉ��Aѹ �޸�n�)��_�⏤6�wVm�ތ(f��Z�L�~����Q���^{�zz�fQHW�6�~>P��|����r����pz�vf�������[�F���og�e�-���U-VA�.�ٛ�s�-����#��*�ϗ��ODQt��6ތ���Ϩ�x`��\��y����y�*YϢ���W�|r2�`�� 6�о!/�Io�?K�н���'�������F��y$�J�Qu�����L� ���u������}�9���/L�B�A��7�b�d�XұKь�X"q?��fg��#�R��I3v�@�?�s���X�g�afL3$3߶���f$�����[��ߕ�{��󿨲 WX�K>�_��ֺ�\��Să���*Z���H':fz`�9���B��e����=g�Y�]*��i����P2�]ȏ�H����'*m4�9�M��9;|����)E2�u���Mh�~�Q.�9V$�ώ^�t) �vVqV�Y^�R�J�u�߬�Q��X	�Y1��{?��}s��dT@�D�d"��_��HS<�ٽ^"\�d�H�F�S��SV���=�g����E[���ʵq�a����(E�O�;�1:wIH�J8�*�����n�ut���i�5*�\�lR<��gg�{��v�q1*�J�Z�>�_�=ev���̇����F�J��[Ͼ����<�Fe�Ƹ�3
E���~��wb��4�`�#\��4qX��m�D:����Sn�v���4���xn����W� 婳[?�W��f@fdz�̨2����)������iTj���cU�����Vx��ޘ���i|�I�
D�Ҩi�Ff���Y�����9R��G5��|?Z�@��<�]�4��vB�>��1�`?62;6H������,��ۗ��F���Ej#M̚|�f.�%�߀<r-i�`).��Z��	\�m��M.��k}r��ZW�0|6�ƙbW��D�|��P$&�9R�jg���"%6��iQt����-y]f��	�Y�*�)k��A��A'�deN�y��Y4�+����Yt�H%ג� Uv)��>4������24�A�͠�\�7����o�J�:�8�sD�k�����^�}%��Iϗ��t��iX��y�]�M�lZ$�6���-)�����04t�א�ZK��֒���Z*�2M����~�Ϻ�� �mM�Tjx�%&�Ȟc8���,�;ͣJѤ�?+o0��׎+�V��=#	���E�o�L�n�Ƌ@�ÖY���{0O޸Nq;� ��[�/���]�>=�E8�-�ױE�%J^B~����o�m�9`�>/����q��G��ǻe��/#�H�ڤ��9-?�(jBzy���A58 �P|����מ�@��m_��d�f_g����4/^�ӊ�s����.�'C���;g䌄;tť3��:w��\�D����+9�\_N�3tFS��<��u�A�k����Ʒ������'������q�Pg�t�7��wחwNߙL�UG�q/K<��[]f%�3��xΞBʲ&��;����2��@`�����w~`����
��1���G�\�?i�\dFU��)���I�ۭq�[������	_��d�/Q9ͷ�
��WY�[M&M�����}�%��7Km�E(W��jI0~�P=3��8�W*F玫�6 g)=��7��ia��҂��2�l��on5�O�����ЫA��I��?f4��4�d#fiH&2O�f��F�h� :cF� �D��<2�ţ��n�Qb|^�&��a*{�%�oHҗ��������X�X~�#���T���������,1nS!^Z��I $�K��D0Go[�4�%�Z�!12Bb��Dߋ�y�컇:�6���VdM�X�F�q��V+��j���Z帉L����^D�N�P��c�⚾��A�id�D�8��U�ıW�OU/qL_�&�aQb� 5{�)dp�a�15��O�o�on���a
DUA�!":�Y��|^��q�������l����*���[49�o��	i��	���\!R��O4Oqj�9K˨6`Q���e9�3�f����So�_�4M����:�!S�.O$:�� zȠ�۔w�W:fc�o�>\�-�O6<�D<���u&�Q�+��f((r�e���!�K]���I�(7E�׷�h�����H��+c��$�� K�7�lcw��ȳMM��ǳ����p`�:�|�|@$�*�2=[�z�B.@�1�[��J�M׌��{fmyO�O�E���7#ʗ�ץ׈�x�|8V
[/͊ܧ0�Đ��w5K�e~N�nj6&��~�ZeY:.�`p���8FL������_�(�C7^��ھ8q]����KgnSΗ��QB�6� ��B���
��6?{��l���	� <�K���U�۷�_�2@�\(r�L+^\{�,|�{�
ϹcX��.%C��g��C��Z����T:�e�_����N8b���)4,"��L�	Q E����b�$�Xs��1��L�~>=��N�;s�I�\�A@}�\��d���e�׿�_����
��O[���$��~�i+6�Iy:^�_���)Υhۊ镤�ݍ�%tΐ�}�̅�Ny�xo�>3�2Q�C]�.$����`}��#��*�������ڵ��Q
��r��΁kY�G-.闵���i$ѱ@�F���zm'�߸��Fln
s�|���R:=��q���9y0*A_���3�)�Kh`;���r�Q����׮�e�h������	cܒ}$����(�������;��iz�q5y�*ɂ>~ꇻ����'2*N�&�����2����0�OtB�T�����=#�~��_�9Z��dÎv��ץe�
�(H@ۯ+V���|Q&��v�^G0i,�:��ni�@�b�O͑���'2����<��,�@��ǻ������NY"����rRP��>?2��Z�D�F��T �$�P0- ��sr=q�h"jvڨ���7.YGF��Ω��5��v�|v��M: ��4v���H�W��V�׮P�8f�a�+n�<�{�x{^?ۉ�׊:T)n��c5��$�W!2`���FvfX�1��хé\�kN������uD��]���Q��/�u�K�a�k��7�K�'�N�N�F Mܼ��w&S��N���A��w&Nڙ�\�p�e"A%�0��B&h�����O�Z�U�ǹ�a�?���b��\�K��L=�4m�3מ��l�9E�/�g�Q�ݥ�t���x�8<xSA�/JoI�:s�.�    �h1���&��� �g�r�3�{�3w���(�}�R��))��41��A� &���dI%�s=���Y��afH,dēy���B��NI���4A����DI���g�a�E3�����{W\_�S*�E�ٙ���p|��� �mw�|��3�=�������H30R�C��=:ҥ��[����I-���L����8������2���k��P8纇��:<|S�yB�H%������J�b9���/ջ=��r#��.EnU�:3
V�iD�\B��� I;Ȳ♑�m�eƇGoJ�Y/-'�8N�5�r'�-g�Q�
�顢�����k+�����	�H�`�d�)y�yXA`	j��/���U���E���o���MMm�[&\�ϱ�z��H���N���r���ȡ]�~7��A������)�d�D[����ϛ�\9�vcH�pA��Y��\���@ä�\3Ӯ��d��*�QIRlK;�ޔ��p��عM�OU��#�g��EHg�M��fܷ~.�e:0N�v>7��/�c+����=�Ul	�0˃e"Z%���D�0�y"�>�P���㩏�>��Fw'K��.��sކfs��J��}x�ǯ_r����dh T���P�͉S�q����N�Ģ�ɬ+��f��!r��}-�est�	��3�|Ы\L{��7m��as�-2_Ϙ��Jx�L6E���M��e��I���]���}�s�i��7�"�1�r��nñ�&���fHw��Bu�P<E�H�f�%?*£��ʼ-�)Ut��-s�s�F�/X²�(��71��5��d���G�u���wel3����t�^k�����P������*�b�4��U�N+�!�o�YB�s
_F�QFg=AJ����qT�)��Rʊ���6Hw2��gF��TEڬ�9?�����H��Z�H�/��*W��쨾Ӓ7�%c��j������n���R_��҇k��]�SrX�j�zY
ԏ�v+��V��& ��+��J��@�H�mu{�{t�[�7��n�1��I|�}n>�o�1�����qt�[�7��wR��L|���2H=����mIo���-���֒C��8����3�M�u;��v���i��>��*'8�BЪn{9�_�J��X��W�㦁%�ƹ�	10hY�5�ךܪ�g݈���5�#m��,E�)X�*�jSF+����g楾�B٣�G$
�ҥ��x�@���;.h��[=�ur�q>QQ�=;�O�������v�iצ�Ҍ/�g�EO;g4�9j����{İ�������U,IUSYn#�i?:�m䷵������>���7Я���kP��#��*_勍u�t)�o�/3S\�L���B[�uI+�+����R���r��"?d{������0�99�~F2b����h:q�����fg���;��LEә�7��E�¹ßİ3p7=1h�w� �ݍ�����Pº�i@��DO�[�`��*�������8��vF�*��,@[���
N��������O��"�Ĉsz%��fX{�3ĞHg����P�>���CϞ ���������4)-����3�n���B&Ú��k���UN�5jHF���FƂ�3c��h� >����Q���՝hN�"%�*)٤ gtV_Q��3~�U �q����s;�'30F`������ك�>�'�"�$��#�8���~�5��Р&@�FDj��2��N��z/�2�sIHSK2�1����D=j��R⶘ ��륙oP�D��RԺ6Q6��.>>yA�)V����>�aq�Q	/eȫb���&T��,���3g���y":�֑	�sUx�=�g4�u��r�̰�\:�E���!�8�u���t4$J�1�p:@e�i>��#26U�oK;��^�H��ٖ�����/���G�}�ps�����\��R߳+���y����t5
����rE��F���8a��7*�ۻ���7�R��sɸ�.a_�������ӽa𩑘v�����%�. ��=qG��y�	p_�$MJe۪
F�Mrh'��JY�\	)dV֖;��.!\�)���߾<'n��A��g�j���**�YĽ�C������W�O�ފ /�՞��t��H/'�����W��ڧai�+b��ҪU���H��|�g|4�Կ�p��v�}����_� �6E/��@/�3,WnU�?ȶ�pu�����(%e��+b��I�����7���uKG� K2����qȂk����ы��H�d#����_��o�L3�L����ٓo��)�����;�����P� \�ȲFl
��Ʈ���ײT���s��.�W�E+�
�ZT��Ѵft�>{Ya����")ѬnM_랜~�Q�'V "Z
s����S�/�Ţ�}����'7<����
�J��	�Y����q6*�)}�p��^	̄�rh�]�1ͺK�:�DS����Z��`_��|�}W|���D%x���{�����{	�=���Z�{Q?�kU���H4N������Im���`��*��ܨ�D�='�{䏋w��O��J�qa�� ��[Iq�}D��+E5�<��6h͞_'�_�A��vR C�_{����˪/*�%X�������QC�fۊ��{,yl<��R���߿*	�֨��#f���I�Hmȡ\�p��8=ح��Z�OׁMrG���Е������m�M�K�"�=�}������#&�vU�������g��e���/=�֤�qO�O��7QIW�~��v0G_|02@~�K�,f������E�����lOݡ�&!��6��A�f����2W��0�/���C�ą��^��<�9!'1EfTx�-C�@�`	����=��,D� 2�B r��R��!��_�T*|ۉ��T�.����ï!j���P��*kg�����_��xzz�*�����,���M`��ώ+�D>~�%��J��k�J�2�ˉ���t�Zn�sn�qɏ.��w7��{�׿��>0e�׿�G��i�=����M��ϖ{�+.F\ܠQp���V���oibd���.���*`�����f8p��j^�ć"��r-�� ?�~��LE�s��^,n�ꌸ�������A�t�Q�Ӊ���_\O,���#�A!����2��tL5�[P���v<m�id����vE?a��$~ErP��wҰ���~�Q)�i�m��:A'	L|��(�Z>�f�\;k�]��d�	t7z	��2���|P�|i1��o����:(˛i��$�)��.�]�3�,�l�.FO�"�SR�P�=x�(���/ٝm�]������^�\'�������L=�UT�*��%2,�Oan�7,+��Dd9ȶ���nƷ�5�@��u&��Z�P@eLϴ���A����������A�Z�Vo�L>pL�;�7�oWĶև��Ic>B�H�[�m4x�q�$���7�,t���W&����M:����j��|�y��?D80���(�1��z�3��]�����L=�:|�k�d�$�X�mj����ܲ�y��7|��@Q�8z��k[6�
�����r�|��V��zōә%c��%��E�>=�NL�ӫ��nncZ BX�'������W���� ��.����8�٣����q���%��PC�#%�)��KA>X6kl����q�v����C�?���o/!ɡ�OS" H&�Kn�:Q������5�����+�RQ@����l�FQ��Dɒ9�����ie�����Vי��������u��U�3j�Ҵ�w��v�N� gJks-�}�"��ظ�hơ14%y��z�2Au�ƫ-���Ō�'�$�5�o�q	Pn�D`�u�rL��ϛඊC�&��p�n�|y�r�%�}�ɺi�H�%f��k%��k�P�ϣ�L�X���B��<*��k4��\F:�eЁ%R����iB��z�3^�	O�3��'����k0RЧ��߶wP��j�ׯ<ap�����=;�Fg�?����93GV����dK"`׻r	u��c��_y��(�faW�9�SI��I    K.bf��?�S'Z���9�V"RF)ɴ�~�a�~B@�H��X�fiY�
P�ڂyą�1�e@Q�cp� ���?��=O"��c��[(K�q��j������i����� ���1����Ia�l�d��H��
 ��D��T���j�<ߝ�m���������M.�s:$�G�N��ְd_Y&ͭA	s�z����\�(�6�)�\�y/if�'��1��*Ƹ2yOb��Je��S��B�	 �lN�,�+�������G���Q"=S֜�ʅ\!9�U&���Gj4w�~�Ƥ��"�� W�*g��ծ^�J!xS��en�$�<i���]�ŋ�m�Gn=�E���V.�k�p�e*���|�p���k[N��b�(�or9O,��8{����i:!�r@j医���zrG@PGnk1Wa���i4^�4�2�쪊��Ei��(��1���5{�3��>����CMa��YE_Wj/r�M��.��N�0�������
2�K�{ ��=�Ƣ�P� dI�i2�؟��/���
4b���ك��a�g�?Br
��}���|	���ddV{��rї��\i�,&i�����r[����}drN�:c u�Mz�]cTL�*~�����bA��YcHӬf"�]�L�����iV���0{�����R�S�^L���t���xL߂"�!n��/� ��׍�UQ;�%��d;�
��!�RpwxP�8�b2��j�Ϩ������/�9�|1�v���s��BPl���R��-�2*@��P:~�0�ұl7��nU_٪:�
�����E��}Z��ʈ.0�fŵ����Ι��E�=���c>�����fS�e�0�ņ����}� �5����QU�D.A�>Y)��%ߏV�Ӿ�}�� ��Z��L>���%�1ji�	N�`�W6����+r���z�r+IaWi��:kR ђ����kk���q�B�Q��ж����n������J��4(2����p��|nRZɌUg����-�����Ţ��� &9�I{K�N�Ȟ!�����N�<Z�E�27v
��";��X�l��J�UWE���4q�|jȦ�.*�QiF)�H�d�Ҳ�A�`��_aQ��P2�/I�1j���29���0�����T1���h�j�4J��c�E����!}ё`1�2K^����+��H=}�7�'mI ����U�����3�e�M@��J�xr{�ʉ��z~��l���"�J����o�Vs{�Z?�-�WX$�>���M�%A+%j��Od^���s��L�9����Օ�
cY.��
<iy�v��5�wI��I��1�,�8o@~v�>������DR��dۈg ��2Oa�@�~�[ݯ��=T\FpbA���>�ܣ�k�2Q���߁"t|eC&zL���u�][�T��W*R��t{X?�-�WX�q��%-pb~&�u�_�5Zcp�� >��h��b���㺋J�yEO+
�e6D&��n�:�����
Iҹ^�|\�'n%)
FdQ֬9���she�2V�=�D)F.N"���O�h¢)�D��$��}�U��Bd�c���{��}�")x��;�/��>��`"	܂ˏ����4Z8�뚰TR?ۭ�Y�	>�]����r�e�M�Z���ݚ��5��5�Rmp86P�ދ�?n����n�^�zUZ�����1�!W÷M���尶[���R���t��I��ک�ځ��O3ǣ]evR�R�pX߭��X�Z}����d˗�Je�%Wi�ʶ�p�n/uݚ2ņ�Nem~�a.kmʱ���n	_�VnF�V�����*]X��,QS��f��ڟ���]��R}xRi�� H���}�
����p���i�M?{��D�}4U���̗i,�uU�sZΤ���v�gt����N罸�iw��Aǹ��ZH����R4;h�������߳��9`hѕ\WL:���K�y�u"i�z��(	�ho��(I5$��=)D��9�� �4:���mk �%*�y��oHlh��e8�
�;d�������Ss�N �mM��_�qH�Y�ξI�P%Z�ZE$��[�r�={O/9U�����z�}ei��~k�g�:6��7,�X��LhN]'�c�Q�g�.���[{$=O��VY�9x�9*�)�:o�������ހl��}kr�{�!ri�N�K�fF2#�W���x'�9SoEMO�|w)���{���<����U15�rE֟{dF
�Ӿ�	�3�R5`�K�#��
�����NԆ^G����SQ�"S�8:���ZO���3�'��M�뮵G[���g��=��3��q:N;�=��*��5`�Ƥ�X�`M����{�`��{�*t:*� 2=p��a�z�]wz��u�Pq��������b��� ���_�w��Sz����R��Q�[[囬�q-���n�řg[E�1y�b��V`A&(\�4抷Є��d'i&���&AN�͋��~f{r����#���h���ONT2D'֒~kf_;�9�{�����W��D���A:�s��%mQi�x�|T$����h�{���R��ѷ�Lp�P?��^���	��@�j�F���,جI\�ߚ�:�,��>�U��B�L�vE��`�;���	�P�B�h��*?R��"yL�3N[�i_PH�b`�h�Z�i����x��i)�*z��kr��� ����t������+:V�ɰ(�@~�4��{�b'�9�r����C[�P�e������I�Q�����Ҹ/>K"��,��oM
d�c���!�;���$��❢�=p����I
goM
S����j̢�� ��ܦO�M��DP���F��M��n{���y���)���r-��(d�U)� b÷5����k�z��7��� K�@��-՘���m	�rKQ[h���ߘ!�i��on��믂�V>����x��.0qk��@rj�a_ܹ����t�-�� ���|�Qv�������ĥ�Ҥ ����Į�c��l$H���[(c�����J���z�7��AQQ�R\F&]����`�V�ࢗ��r{q���]4a>���9�{��g���$�����R��n��k���l\�:���]�7Ʌ^�U�\8~P@�G��J�y�wx���r� /��f��j������������h1�#	��P1� ��S�_c��O���Q��<�s���Sl]���:���w�c�2J&��&�8C/ý=�`�"�?�$=�s�������8o*��1��zy��˝^�~��Y/U�IW ��x�|]Jx��l�d�_�.�������5M��!�hB_��j�����m�m�G�18B��Ź]�J���Ǎ���4��kZ�����89ة�N�~�j�1e�{�ϊ
����L�dʝf�nBe��'�@�c��W�O��B�����ᤶ�͝n�n��ޒX���j�U��⹾�1SXW�W#�I.�5��T��w&���ʝV���� ��kz(Z�ɿg��V$��Sg@�Lzb�6�.�Ro�)��t���8���R���3q���/o���J說�ڗf�|#�QF��PG���,��O#�
fK�7��@�i�3���-�u�.g�O�^�$�2���K��L� m��b�e��тb=R,�ί�Ȭ�\�G�Hp:|�i��L��4FP��������;Ѻn���븥�M>K/��y}�QE%e�)ZQ>�_��+����j%���t �˓�N��uM,��@}�F	�Mi)�fd=b��~[R3�f�ÁQ�����b"o΁�c��4f�u�'�۞kP�;y�21j�� �V�ҭ����m�*¤92�A`�zet���W6�K�\���>S��Am��	�2�V�s{�s���Iue���nb��60/�¹���K� d�PW���V�`C8������'`0�f�Z�����C�g�YH��mW?�uB�㜔�3&�=r���!�Wm��O�$�Y�gs;]�Ċ��@�I�#��\T@F��G�'�t�̤.�]P�ѯ�$cnt!�耉&�M�ƨN
@���
�q�XU��cL��&3"?    `��p�]����t����}:�6O���K����	�$y9�4�+�%�����Γ�^%*T��n��V�\�0w�K����/vJSRʕjbH R�qQ~s��	/wfaJ��qW�i@�ϒ���2������:�}���c��}.���g-�/�7�,����Ϋ�R���kEmI�Ko1.��G��g����R���Px�Ѕ�t�`��>�ΡA��;Pa����+n��h�P�d��$�Ƌ�N�ձun���g/v��X�l�tq�ㄻ�h8�b�r�p���DvZ�*��^촊qI���/G�T����S|?�d��4���U,5<w�UG��Cډ�J��P���&�b�d��A�]�1m������m�4���P�h��X�H">}ПDo�S~;�_"�������#[1Y#��0�f����^�'�ȫ$/�<�=ڟ�ty�o��W�B����޷���H�М��b�����	�ڵ�s�,ߢ,�.�W��_p#��%��U���K��`XO�_La�H1�ό�L�G"�v9��p�Ű�[ ��ӷ8�BtB�g1A5�vF�t#��܈�x7�e����7��GW���pYTT�0X/�l�	�{�l�C�AO/�;�I���*�cz��!=�8�`6匓	 �l�nM�B�|�nJu��2��m������ ?퉁Y��5����7n�+t>���-s��lD�G�C�\��ߺ�g�oM:��ֱ
4�[��~�y��V����&���9�7��g"7-�R_I��e�]�X���~~��9�у��$ʮW�g�p�Q��d<�L��ŝEL�=�
�jS���lq�G ��M*#���bB�a�i-ҬSg!�T2<���cr\M8����bJ���h����Ȭ�)]e�83��Z)F�+������ PV��(Y
E�d`Ш;_q�糅>�s�L>����w,�{���\�Cte���E��4@������kJ�n5�	Kz��ާ8� ��Q�8����"�:��d`���dz��'#;�XT����G�b�l[��+�r���'J=Rtjy�D�ǳ�31�׈�虍>�
c���K�R�q�FQ�Dd閖������\�g^�V�*�L R~/�&��!M��}�C� ok/���|�)M��-�X��	�=���||�:k�F�+� �*�u�W�Jˀ�^��q��I���]?�skX���a���|i����('X��ti	m���8'ö���8���͠��;���3ָ�Ģ���-��E��傯_i�������	80��C��>!%T���T�H�4L��pq�b*����E�|-k��8����8��>�zHC^� �!� $�22���HBp�h�Fyׯ�CP�G�����h���P�Y-���/����?����\���o��g�\�&mY8*��&$�?���FH�R��z��)��~%��!�d�r�Ti�k�*����t����uE	Y��p���5��[�.�Z�T�T)-UVf8��tk5����q�d�RҒ�mpI�4^o�X��y�4��=O� �ҟ�'����"41J��T��s��g����:�<i2'�� ���Ɍ+��:&�]ꈟ|��|�°׭J�T�om68ƨ����{q�T���nN}OoI�u�:d�	|���e.)��W��8� ��mS�qp��x'.S�Q�����D�kܔe�bc鼡wx�1.��Ϯ�z�ɺͫJ�	�Zv��o�P�ZڻC��w��B"� iyWV�V�&���V|`�pȞF�a$���DD�Υ���eߙ:#��8�i��ni�:]g��_���X�Ʈv��'���� �\�]��Z��8���\�$�zHr�J���g�ؚ�B�YRvbd'�j�\g"��<A�[�Zj�Vk�����f&}_r��l:';-�f-p~ݽ5T|�}�ƅ<kj�]ˡP�n{^6.�$v ԕ�醎ҕ!+'�|MwI�K �A
|g6g�k~���>#�mć�mGJ�%.R��V�~�JY;8�i��:�֜D��lኳ�!���,�|�9���
K�g�q�Ԓ��{���}�S���
\�(��'fA�� &'�W�P�]}���b����T�9߽�y,SD��A��h�y��B��Ӆ�����;@������̣����"4�KhZ�ݪ��W=ˇ���wJ��ڟJ�+�����J�Bؙ^S�\���}^-L�!�7#�@��	L�^�y�v͖YC1���� 4����7gB.��)�榯i��l_|�GNQҍzg��)_V0|nF�� �x��r	f[������$�':�O��J�����vEh$�v�������>+�"�pe�!p�W��ƕ;X�uH%z9 �S+�Ý,?+K.���2s��Ȩ( ���k��#�u�ѯ���v���0s�Jq��)։3`��\�5��&چ"��?o�H�R�S�)��t�Z�v�ۿj/w��I+��S���<q�v��g�ȅ��j�H�]i��ի��6'Duk5�I��g;�~V�m��|�]����=���8��GⰙVs3��ݍ�<�d���N��?r\.E�Jmq�z�Kߛ;k�9ʼ�!@��#BW
ղ�:��u�.���|�W��v��/=�➁���H�"���})�"9E�Pd���\���H?�`���A[M]m'�|��8��S�U&�7I�YwD��b�䤠k<]�n����V?�
cͷn
�E��ZE�"IY�w��G������UB.�%#ɓ�ro+ya��ޭX��肟|'+Έ�8 ȟ]l��%ٝ�X�����b�^r��
6g�#�|��Ov5{���˔l��K=��D�^���H-�	��ÌdhT�:����v���W[�T?��"�=˸|�~���6�5�z�Js3Sh��䢦~�56���o�)��-V:kNͲ4�J�&ʮ�����Jq�=�K�3�5���lN���h��I܈�.69:����a������e6�ސN��/�P?�i��'�QJR=����ҕʈ�>P�+�C@vL���]����!wF7�����@�4��G�{�^�&5p��V�&q�L0�>͵�m1���x��q���q{#��3��K��b:�ܿ�Tbh���'B��E����%9/�g3�ʍ�5Y�tX{	3ؖ�y\�^Fa�����?̍�/%�[in��W���(,";��rm"�(8L���&�c�����pi9>ښ�I���+�@�1c��BF�K�Ւt��=����;�H�������	
Pr�š P�s�?���'��W�t��A���G/a���Ҷ�6��:����-��)Y�+�z�s��L�����K�ֶ#�N�wp�S�\�iK����b�Z�l�2I�f��l�N^���2�}DYg�O���$��k�7h��~ S��K��i�솢ڥ%x)�)��q�k�3�O��)[2�;'r����\� :.�ls7����O3�t�D��ڒ�a�3�:������f�ʃ�$+��������%��'GP�;�.�GQ����EŶr�Ĥ~ǿ�:�=�H	В��˷����s��x	a} �I��t�
# j.����[ ˸K�Rz�.3�������b 'Q\�(*�ˣ�J�7�L�L�3鍦N��ԙЏ��z��=�w=��B�4K��v&]��E����:.���v3�ܜэ�sh��-e�՞p>RW��r񁋗E[�0+��RՎj_ud��ߞ�տ�`>�Y(nǎ��F�LCT�5�LbJị��9�h��r6�t L�WP��l�R����לO/|T1W6�j��R[��Vڢ��l�V$���&t��#Y@�5s|Cr$�; �c�ל_���KV�i�]�I�k�x�f��.A�����P������;�X������ �;�*T��N�R��*U�\GjAG������
�1]T��dg_y��uc�9�K �VK��JHbhJ�q���?���ͺ/5 ���#}�6�lC�����F3�g�	�oRF����X�#:���n�tػ�4]k�B�~�i���^�I;����L�?��U.�Jt����� �H v�Р 5��z��E'��Y{�M
��=@�,��2�e���    ���aQu�߷_HX��{�!6��PA,�����4q�&3�@��S����Q�da(/m�}�����z����q�UP���[��O��0�?9c q���TW@mG�߽�g.�z�O�{�w��%^��%N�RZl��\�G��3�h;dLɩW[���P��C�+���8�Q#64����4�k�}M�'��DUQ
�T�)/E�^�����'t)t1;;9��y	����_�$�_��:U��~A��b]��ˬ�"�$�e<���'��m�&ba"�U`��
3MSː����᷸�%�ġ��5g��R��l��
h��
�{����(����jM��q��sb{�u|�-�F��gg���g�>X�	��J�<*l�+n4\�K*�������J�O���|��Le-�BZ��O'�p�ǃӨ9����uD|�z�Z��[�t��l����Ere�u��d)kw|�˾��������^/�no��Sb��r��|�k'
G�B>}$7��G����gN�鷸
E1O\?S̓���zD�Q*�	2K�i�ٷ(�_�鿤�%--	A�K���P60���c߽.t���&%�KPb�r]nT:��(ȗ6�Us�D/�`��M$
�p�5�#�DcF���=ߺ�IR��yd�b������ȸ�?&v�0�H� �-�N�DO���-�'�y+����S��2�S�2z��*ԫLi�I�K{��kH�4�T��}������=�4�	����o�*�*.�:6�Sn`99x��P ����}�x?��P��O�P Ҏ���(�i�/򍏂J�k�<T ���b��a�V��^���b����5���7�-�v�^*&����؉�^G�4��W�d���Ynp���э�>��n��:Vb����h��Q(Wh��K�䤚�[�K���\YS.S?��ˣ���2o���X�0�!���ջ�9��$�<)!3J��h�4|���R!YyE�L�|�¹���K�MoM��*�k����4왖VrQ��နZ1��j�����BސD�F� �' #��L����s��Ba����h�����ѹ6�IlG�17|�r+��~����U[Yj���u�so����qٞ�"�0F�Ɍ�Z��H�5�a����P�EJ{u��R�O��}�&o���re�RU�����֒�k�}8ᩧ+��g�A��v(n��\l<#s��~�j)�{r�:�ӹW+�8��&�83�6��bј�ei̕�Ы6��~ �r��I�"����� `�h�oxv�����!�O\��1�c]�u�in۷/f�s�f��o�AvS���W����	��2�~g��5_�;+�G��RRH.%7H����#Ɠ���'�[�}�G�Ǖs눦3q��Ĕ?:ψ�2o��k�'���1Xu��gt����#N��/��ƫ�UXK�����Y��
;��o���<�ч��z4�;qᴦ�W8�3��'��z��7��bz{���Q���,>8�^g��x�9pZ}��xܙ�wc���P�G���{���i��C�5nr�	�������0�R��i2�L��V���(7: +2�9�w����&1��V��rm�D�K��5�]q�@�C��2:�1��]`ܮ���W���=��+m��� _���+Oߠ4�����o���E�M$�k���ɡ|��)OM��f��K
a���pf��GoPf��k�dUy���MbI�gi��:+��s	��
:8�R&5��t.3�\W
�S�u��]��+[��A�vb�	Z(��\��kC6v2��>X�3ڞ��[P�0����%�>j���O-����n�����$w�>��D�(�q^f��u��y"[H��.CK�KZKv�=���k=S��7(��Re�kƃ��i�7��ҋ%nix& ���j�#)��+��F1�GOz�IY[�	k�KG�H�nShɏ�8��H���.c�9���+s�N�ޠ���W��C��	g6�%˪iu��'A1n���d�i��h����i�ߢ��T)�͸�1�	yD|�ۨ�P�J'�+��(v��:;x�����f��i������p|�#4��$t/Z�&^��ёki��\.CF �1NרC�X�ϔsnsey�>wIᄗ-���G)ܒ�N���P���Q���r�ӫ�p�Q����=ۖ������9�����Ni�	dYe�G�W+��A���$�`JJ�;Yā(�
$��R�!���v��?)�j����	m�3[��b�3
������̒�z1�Y�WN�<�?< �	���-n%?��/��8 ���h��|�8G��ןὗ���ӛoIo~~����qE�FU�����'�U��ow�O>���)�+#��=�K�(�A�w
�-)\�o�*�͸�����f���<;��ŷ�ӥ&U��:�����`mbM��Y3�����|�>��R{:���j=ώwj�-�MQnĤ��5{M#��U�Z�f��p��q���~o����@Ê���d�Fߔ�m�b%�9��d�Nkң�I��|�G4���8�
�!����R��ҋs+�ff����F2|P���R'�"C+�ұ�1ecf(2��ӇoI�\;#�2���BqHq�:�\�(�
0�C����y�r��Q���'�F�,�����8bdnuA���7b`�����2a�CN\��܆�8����?W=���FLͺ��kt�\2]B��m ~��-IT�:}Pl���W�T�HB.YN	mi��nͥL9_��7�̇��}��?�?8D5��{vC
�*���B�@s����e:<���7q�޶�7v��[ڭ���{���:�+Bځ-�v�qW�cӞ��w��Q���JF2){/L"M�|�ۭ�C�[K���o`~��B�e�q8F�y��n�~)9��H.���f��ަ���жt�(G��-�3=%}���i�zO�Q���)y_��nSr�[���F}'�_)D'�UhI*�Gk-U(�!ߔ�
Q�x�� .J��hŵ�8p�"�`ª��l�p�
�n��䶮�m�N06>.aO	� :g���� [KЗ+qe��#g�E{x��d�dr�R#�J)���n�~妹 '�	��(ϐ��&h�6�蝭�k�$��$��r�����>�u(�OF\G��{qК�P�G��4������q�JM�K-�#c�`CTq�O��@�ס�@�d�3�	si�ۏ�e��d���r�P$��C�
%����x5Nw�������=n�J7��:IT8K���#���a/�g;I�ZI�H�#-�9ц[4jF����ĵeU�W2��N��V����
RK��S6����yj�OrPv��u���r>�6Z��_�7��'j��s,�)[�۰N�Π�](��N߹s�@�����vr�[�Q�o�j��
3e��[��]ii�R�Tp{�ʯ�6�|IO��i��?}#S�G{��H  ���[= �W��o3����1d t�l��v��/t�]��ڑ�Б�5w���o��+p+k(]�c��D���(F��Щ��7�%9�]������4��F���������t'�A�`�P�tS��<�]A��xE��b����AsᖺY��d����Hע��g��xu��k"�?�U��N��O��?���BGu���:1��t�] ��~L�9�Gّ��(9_j�a�a��"5v��/,�U"�����z^�4�dq��7�.�n@�s��K�����٘<\Z+*���Fu.7z��T�8����HHK�Ref�z�V�I���̀$�#7�UT�+	&�4j�,�g#u�U�E�Wr-dd��\kZb`x��
�P8TEgI�IeΔ��ep��K3��x+�ϳ&���f��Ne��]OҞ(_/ �N���@FH�nIV�:b�Z��N�r�n���˗��hɈFJs� ����+�[��u ���mы�0C0����D�ȏm�< 5�f���a�E3 �gd|�U�?�����+�sl��f SM�Sb����[V�z���N�*�&��iR�d�XR�ި$H�s��뼏����[��v�Jg> ?�=�2�7�%L    ��ؗ�I׀��8+=��������B��7��6�fz�J�a��:9ΐ�/�����Y�w	�i+�<�&��{Q��T��M�tf�-��r��)s�N����F�tr3�np�8�?{o���r�	��_d��}o��H|�WA �.u_��#$QI*��|�lԞ����,���{��ݞpx�C㘘�^�? m������
��'=YzO$��%>
Uy>��9����;G�Z=���u�#�>�vk��q��Vo0��5��Q{<�܎{O��ގ{|�@| �qI���8�#�'d��y��M�@�HnV�D1zI�Є��b�7�t��i���'�o��t�eM�P��-�g4Z�[$Qo�	�Q�"�����Ѭ�9�i3C���<U }2�p�G�|\h]��\긢�%68]��!�(�y��w��{˯�x0��j�ZN܌{��5ZQ��#��s+��Nݖ�2�1�o�]�Av5����X�$
� ��H��d�� ���G>)�轸�{H\u �@vF�|�%�ya��
�^�֓=��a("���%�����#B�Y$�μ	�;�@�ThM��b���e���/+
�0و���t���A㇒��OI�생I"�X i	��	����aA��$�j���Ub�U�(���4�99���`
l4Ͱ�r�3�*)	gf�.������ǋn�V�5q�Tv�X.���u���I7ms�r���8�{��{Ɇd7�,�P~�M�����L�r�">�[iq�%| r��]�����z�ٗ����V��3-�n�፡�m��=iߞ�O��Ǵ�e�͊��~U�����3���I�������z)���~��;�r� �	���30��s` g�<R�0�"��Gٜ��H<z%��^.�k'�j�|�#z�W��g��-<��>�9O�*)���+�d�o2���f��+�!��$��pp0��cB���I�vK�rr���I�ɠ�H�iq�� ��ԋ�2�����종���\r��(��T)�bߔ�>	'᳏kw��O����VmI%\�3�0�����Wiwx<�.�=<�Cd��(v����H��F;Eil���6��F�8x#G8�Z�o��5僩t��NǇJ�N3?({�ŧq�{��
�2\|rB�!A��l.*�hv���cq�擵h��=g�T�r�_,��y��Vg�&��f$:q�|L�Թ��R-\9���P|t�m�k��eI��uGt[ם[�u��;6G7WQ��U1r��ܦ�ۺtz��f�I,��Ψ�����R�Q\ض��4�}hl���[���Ԗ��'�ýV	-��p�<�A���.Iii�Q-��#�A{��/D"�1Bb1�5�Z�2
��Ba_bE�K��P���F�H��`���s�SIJ�ٞ�]誙Y�
8��e.e�r�/$�t���wݻn���%��r2b_`�t�"�lf"Mm���v[7�5����˭��U�Xi�ۼEt5��o���J���Z�̪'o����A�VZ�7OR���H\����X�Zy��9�/�|�^��V�<Y6���#�Y_d9��Rq���ɒw2��r���IFU�棊mo������V��G49�N�<m=F����x��L\\��T�B��äy�9�.g�fk���[�h���K�5��N\�G)?n9A���N�?9�C|Ö{wK ���p-zw͎�X�"�5��#N��W�'�)����^<��p�2y�Xٹ-gp��bs�����$<ڲ��<��bt�4*\mZq9��*�A��R���R�^?;Ɠ���)���^Η���j�$�YvO`�)��"1I,�P�3��P�9�7���ٴ��DEb	i���Uh�,g�If�6���D��E3��H�P�/�6?Jp�3�ː�2�Oi"y�K�V�>\K�����\Qb��M��M"w�iՎ����������2�q���,�0C�Ջ"�+��I�Z�L����>����5��Koy���Yhr�i�$��a�#Nj�D6H���wNy%.P����-�2��r�� �o/�K���~Xa�d���Y���^>!grMkI�Ցݻ�Z��zf��"�u(��$5T���c�t_w+�@���C�H+��An���D�`�mN��DCZ�z��(���7��L��e���z8z���Uz�θ��F
�^�Ք�0_�K�=��+8�������l��z��r�o0wf$��ur+�d��EE} y���^6�!�=tAZ���t��� «�GG�^}���^����z޷���� �ID�N�&��.-�g��g�.j��~w�=k�.E8֖^|�����?J���7�o�\�d��etm��o~�l�rM!�h�p�&����t�a	���b�M��ܘF��G�>���Q�pEC`��L4�n5O�K��p�;[�d�������*�;2���ωD�tS{KZ���6ܶeD�03��B���zgf]��J�{�S��2�����Y8hQ"�dE��GgT�?$��G��w��yۉ8Q���b�D2��	�V����N+���`��C�Z�%q'x4~)�trR<9/�ɞ�r�A�D(d)\��L���'g�c��v���m�����F��
���[qA���r��Z;E����,Ƒ���i�9�Ȟy�xw����_d�H��C��կShMA��Q�#i�b�IT|�>	��Z��h��}w���W4�+�G�n�y5C��Z�>n�aÁ�/���!;� ��p؎f�홇$�"����WDoO-'�6�RK�c/y��"	#2�����nF+���Cf2(���
V^}M�4�PN�$P�_"�(��yc��T�<� !�p#'$C�K<�D\g�J�M�j���H�����QR�DK� sr3���� ����tj���.�Cc�b�&\�Ƞ?פp2#.��-B�Dف{���h`�LScB�ֶ-=ϖ��l�i�b�zO�a�,�!���(ѯ�C��KΘ�;O�Slf��Ar�� 43����fl �^�������-gs��QZ���
�B)�����n��6��]�n�����1�����k^@�Fzq(@�S�#��K�c����T+'�9��IK�<��?*đ�!F0��L��9��$φ��������4�f�v�e��N�ᑝə�,��X��^�5��ڌ��.���Q��["wD�0�Q8L���\���*۶'�}�Dc����=ʭ�򠐟*$�8YN�C7�ѣ��ܟhO�Jɋ���~���\��qz���f�M��Ui�~0�����7.�������7.ٍC9��d�?�v���u=���ړ@5����x�ZI�.�Wr��(V!��_����v��Io��(���P+�Ta��A�=�f�튫��+ƃ�R7�׹������%����V��<����z� ��'Ç6�g
��n���F7U"��i�-��V��Q�#��;��?p�|�f�8��@~�L/u.�y��zr�����H S�bh|�a�Za��m2���w����r	}�������=�����o[y����A������GHf�r¾{7!]B��5~�f\�靕"���R~	��𠄟*�}�H�"=B�RzE�њ=HH%E�'��w��B'�Q�6����eg�'����C�s�)�-�7�=�k�{Z=(�A�?U�!Ir�q/�B�ԡ��L'۬b#F8�8̡U�v�G���{b�����i��q��T�.I �.f�"�?ܒȗ�M/\�َ�M�;�-?RO����=�k4�̭������W(�f뼭B�Z�&�g�ퟯ4�;e�I�/	8�tD9�R�wl�).�z����r���xH��i �p $#��9�r��U|9E^�l�`��R�]*ڑ\"e�I���5�荪 �����$���5�Ԁ��R{��cigMP���_�a����~9��Y��d���Hʥ�Gbf��	��x�&Kʢ/ ��ʓ��S��]#�N�FF��K���O@�)�������L?E�Ȟ�TO�7+��y��Pܧ`):�    �����ߏ>�����D_�f�Y��D�&%9N�Mi��x�x��TK?�G�E�ل��g��?��_��?J�
a�h!)\z2��?m��������m������iw����b*�'�7��=-�k��Fu�)v3���($�����Yy����g�t'���L~��Q�@�JB4i�Sř�s"��Up&3�g��ꞢGW|4XG/�r"�h�Ŏ[V�?>�1'��D�I��%�]Gy�7:�|��p�)�0Ϫ�ǈ���$��#��k���e��y�`���!`]��&o�b�����9"í~V�?�Q����(�?˘�Vq���ϰ�`"l��p13l˕�>r%����<J�R�0g%����*�1�V��y[��
���~��R�8	r��F]^WEk�#��B� u�<��B�����{I3�퉋�H���蠌7ˢ�䧀E�m�[�o��LE����r����ew��ZSpb"/�����9�H�$�Lu	��99��6�E4�x.��j�Oz"�͓ � �����%�_��S\�#�7��Q�L����Љ������ԣ˓�sB�����L�-_�ȉ�=1��c
�q*Y�N��!��r�t �E(E��F	�q�Y6��O
j��$�go���EB��[Sz~��I��<p��|��)��Iȑ�}�fʵ��4�6�G�r������Z�	o���Q�����IB�R��Z�3I?0[@߇Ռ�:�[��	Y����.:d��/[��%M��x� ��w�.%E_�J�xR��B�в�s'�gg�~��{h��um'�g�c�\�<�����匵����u|���燉q�{81nu�J4y�f��G�F߮	���?����~[���kX�kM~�i���*xѤ�K$��j4�H�._��J��3�TѯzJ?���~���������>�}8G�z�|�\^������\;̵��k�CH�"C}D@��C��y{WQ{�v�&�xN�ȃ����]�'�Η�Z+�tUʇ���<:̣��G����W��A
t�B�e��ޔL8��j��Q�+F�������r�#�9�s�p�H��ۆܦB�`�]ڵ#J֚|�G��(��F9���aVf�>Ί�F��Vi��K�j��r�-�7[��m� �DH��kq`�mG���_>����&}�~���ӡ��tiF�r�{]���M/i�Zp��+��Q~�od�ل��M.6���s�BCC�L��t��,m'o�6Nw�3&���k9�����\ՒY~�d�z���\Q��q��(NB%v��)ч<����"ݾ�:�0�(4TH���Hu��晃��i�)��L�3[E[Zމ2�	�^��B�!�F_ ��~[Y!�y��3,�P��\e�X����46dۯ��E�ȯ�=+֞�g-:���![�`f�4��T*��/�!dJwdA�k�?q��q�vd��\��T��JW�3Z
]!'�½U�k�D��j;~h�F2�hZ�5,d���&
�\�1���k}����~%�*iaj�}_K.�w����]9IV�|�����q����f��h,��.�	H�qf��Ha9��"Q\u����V�۽lY��q�+��Y��e�+�����k��'ߨ�*�������)=@ls�&e˚��dM�<sޖ�c(�H�瑫�W���=npдG�f�$���A��R��=���/��lc�Q�b��n��
��P<��1�7���ǚJ�9�O�Ffa�z��\!k��������p�NB�	�f!��,�
9�{�4�Y�p$mP&F�݊���p�9*��q+h��Ȳ�S,{iӕ&�vh��u�@����z}o�?�FiYiO��l/�Y>EY�ZN��R�N/��^9��'���#y�gKܻOU뽈�����A?���[RtU��x�t����N�;�	͓hLn�d�Ʉ<�.�D|����E�#��vE�ֳЬ�5� \�gw����&���_��gޭB�3�`�R<�iL!��ѡ�<R��DK���B����%�7��q|��0{B�ǡ�f{�_��>A�ڲrR{]��f�(��Y'�d�?�i�4#�2��s��$���?��M7�:��'��E�k�t�p��庇r�� (��d-�Ul����:%1K��gĒ/�� k�m�c�Z��]_�THP?מ�rr��1����)�����%�#o������ďPduq�F$���&y����Ésˉ��ŉKT�����.���t2��T*lI+d~cB��Fi�Ƕ�����8g*g
��!��) ��hj ϯ�}LO\��˵�r����|��(?���FD+��C�- ��6!����"�:Zk�)�G"Ø��g(�X�}ab�^4Г�t���B'ɕkAQo�9i�RX�st�_�N�쨯�d����*�S�PHD*�B'?����j�)��F/@� -Jܿ3�.3�J����������?����O�/��/�R�������_�{�����߿�ş��_�����ế������x���˟��F��9�x�%AT,$9H1���7hI�+d�v�f���i�>d]fpѶG�6g���yV�6Y?���?��_��ҋ�����ߓ�A�2y�h�����4/��<��������s���ӛ�����g����g&~#��)͇�sK�+�cz1r\�p[܎��/��t��p�Y�-�x��.ӝ[������X�×��H�I��H�/��W*^Ӈ_$�������0�[R,l�I�H�y]�Dk���.���,Mn'�\��J���ͤ�S�k�
8�u��F��S����f�hU��4%8G�ٛ�������L����nݚ�7O�?�&�L���d��e�M��q�������Z������[ˁ����_��7��U��g�}7}��Ay�䭳h�������<K����³�3*�N64�?�9+���v�W*����$dXG���{��j@	���>��$	�i*܅ZRLD�Ӣ��S��s"�+��p�7_W��YI|,��$��7"JpA�3P��
=�B����fAO�vW:�_>�<�r8��(��/��� �x��Z�UՐ�*,\���q��e�����գ��ؤP3�!��4��A#k'C5�B�VR,Ҳ�5��o�j�s�#�04Kx{џ'k[�fyas6+�ګ�������EoV�Fy�۸��Ѡ�M\k����.F�aD	��Ȍ�\P.H��&�o2�s���Z�Z�DORt<�i�=4��߭�N�k�i����vF����۹K۸u[�n�׷5t�N��F�\���n���s`VLD���^;���0�e�͜␀�b���R�@ޔ��3�L]�0��2�b���DW�t�uU��0YYi5U$u�'����#���G��e[�x|�-ya���[�\���x�� '��oH�>r��t��I���hv�ä���U*g���ݝ͚�b��dȭ����%C�FZ���s�`�L���q�H�B!-k����r�;~��>8t���`����ۦ�T��Ox����Z�×�$|�Lӆ�#�h_� �2�}COIa,��37��7� �zR�X���5���^t���5Z���Y�9�ְC�]r�e�܆��oԺ���q�5�)�-�}�"�[��^^��4��r�]�n)xfL\F��v$�W�a�P�\�Wh��I��༐��M��yzʯ���41d(%R�Ȭk�������I��(��릪5K�YJT�"��N �1Ч�v�7L8�X�m铢"��&����Z}�t�V-��c���s��3gdm�� �1����{��3��Qngdo���M6����s��L�DR�pˑ��I�4%���I
S���_KT�����������dU~��h3OA�U["t��ah��T'�E���m�me�I ��'�z��y�w��W+��e�'Vps��I��G��f>������M#��s�$�oN�^0��D�	���VF+��q�	PM$M��qL�9�� ���Ù~��A���؄ى������L:b�9iH�-���>;�ي���#Z�в�b�i�Fm�zi5�+��q�� ����������r��    &(r���kt"��k ���8�������~ƹuՊ�瑻���1�:#�=9�	b߸~|rr���y�fi0@���������X��P]��8�D�y�5�X\|�	��sI�����Q�w�v���:���(��%��y]������i����U�KK�����L�mkH�Fk8�i����_�䯄sC�l���]��s�hS>���C���׎�ſ�����=�[{�w��b��7�[|{I?v�I]�I����z�5�7�t'B����� �j�:�����á,؆J�b���S�d���?Hcfz��(@\~��ʇ������<�rzH��Zu����J��}�Z�{�d'��@�������u�z�>��k��'{���j������{/؃�80����j��cDr���d��/��騗��&����M�����_#]f瞼􏹌�Z��q��q �^3^g[� �|Zy��V>c�V?�~/e��K�
�/(�����<=�غ޵Ӄ��Q��E����k��M�|bg����|�H��B��ع�=�|V�ɣ)�3���^;;��>�X��H��P��Xw�,�^"����Ų�N��:���m��Ψs�N�).ǣ��V�}=w8���O�%�݅�)Ї�	��|��b.\��[Fk-MH|q��
�g���O�� ;3ߜWq~yrV��$6�Ƕ:눕%�o��Ц���$���IO�]�u��Y	��(�ǡ���$���{b�o�ĩp��7 Qm k���>9�Ĥ�����R&��b�4�"!�K�y��Ś1�ܩ-�Z�a�K��H��V�Ld��։k��M�;0|2C�j=�j���d	q��3�"�bMDy��10�B��	��,�N~�`]��hd��+��d7Bmf""�R��Xh�uGzq�em"f\Mqr~f����I1��� ���M�2TSI�1#�Z�Y��B�&�-�H-�G>��w�z���AK*�.R(l-*��rB��T8�!n9��@w�k!)_��,�W_'�r�!�3��[�r��M�jh�s��=v��^'e��zJ|���e#�C�UJ��	�
=��Q5��­����L��N�1�S;z�R1����-�,\�I�7�\��TZ��Ɋ��ۘ� N����w�vhd���ҔYs��=���Ҵ�x��>��(���E�3�d�r	*����P�?�Z�Y)2�VF�LB��W+��#bzͮ��lWG/�˄�Ժ9H����;7��Y05a@���(.Z�_�b	�P�[���sr2��Y�]��~}B:�kMaL3w�"��9yX����i{���J"j�Zp�i3z�H^�Z4����i:q��~��v���c����cݻ�Cl��8Cz��}����S��e�xR�Z=�R>�:t�T�h���pj/Õ9=�{����X6��t͜�S4h�q�Ő�s��o���HH�u��v	i#f[�iW����s0����Č�2���i�q�@�����@�9j���hJNl��#&ኬ�~֜+���9��=3���:[�|i"�;b���;�h�Yˬ�vZ�{5#��l�D�K�8{��,��q4�u���gR.�{W&�������N��(��m  �IV�{�����<�TD�
� ���Q��{πKs�L�<L���A��)9���m��;C��F�M���o�Q��Ry�䈈f�u�;g�h��=�v߹u>:�t�K�Ǘ7�ј��;��1����s=�wL���C��`x������u�9�M�'�$�P?D�ؼΕLd����e�j��\q��� �z�\C�:��X��QC1����m����$/��#��<��</�bՐ�,Y�b���5�b�r��04W)}!�Z�^���<=��[�`�7�ķ�~d-��e�u���M�eÿB���U�n �k+�4'1�rн$�t�;��Rҽ}���0�+g��!���Ċ���j�hxb��P놰x��	�J&d7&ֈ�Y�\����~����qM7|- �1n)�)�8�C}�f؊���~����G�bZH�j
Kƕ��^1G
.J�"#I�lr��g������%����+	@E2�G��Ym|����^۴�I��X�v��{���,���v9)Z?b�S#��7�𶷃}���y5{!�<c�� ��� �W޲�k� W"��XKKR��3���̍5��[���H�<�=�UbU����vj'�-��rX����56�Ե멐� �D�1/��ܢ��~^ �qB>۽�=�j�ڹ/嗽���K/s�Dۘ��Ļ�S���g2�k�s��<��Y�s%9�%B��G1;E�����Ǧ;��"�ݴ��rI�sGcTM9��=�~�^9M��>m��i�u���6�9dƎ�k}�G�}߹f���������(2P\�B�5jQl �"�l`�������Ψ�L��lT�>� �R
�v����nk�6�]'�C���it,8֠u�4PE6n�v��]��s����^�l��:��=몕��g�S�%2N@LC���9�\<ۭ�䂾�IA�� gD\'�di1��M����q ��[p#�L%f���t+�NBϏ��P���� �u�e�M8*<�oV贂�2�ǴcJ*��^�_h�fkq���om�ye��t|
L�:��g3��
���f�����ڣG)���geQ)v3o���=�_�g81Qq��켺W�#����E>�7���h7hkk�ņO��ňb!ܐ��Gc�J�B_��{M���t��b�~1I�z��0�����\�R���鷻��nkH.��&]F_wL��U�_�~$o^ې�%�*Wj��~�^o �*"]-��F�-g
�d�K�p�������b�5参��y`:��'mp~��d�.r���)�5������A� ����� cI<�$���L|n����$	g���+��b2��U�d���m��\%���P��W[`�T%���3@d���YV��v2I1�܁���A�
�?A����"��Xq47�zu�ۃ�T�ё�H��Ԧq|]dp+$�u�?�b
�����<�0���$��c�H?2a�6/;;�\��A.��Z�)o�z[���ܧ�b����1�<��d!�aBD���j�T}�L�N��\���� ��V8���3gF��`:�9"1��%�����7З*Ծ\$��|�g� �[J �5K}t�H|� ��`���7�]Lԡ��(�a\1�~���=������3"�?��z����/��ߓ:�iKA[�R=��;bC��-�A�sչû���%6\�y�Ö;��-1���ݘS1���u��Q���FRH��Tdl����D
y��yG���SeOν�B[�T"��,��3���P�X/_�طI��.����&*B�4G�g��/�~����?��u��/֊SN�WkZ���1ҞєR̒Ц�zS@�i���R���L2�$74AE�+u�d(���:9W��=}˼m�L�IC��$�,m��g�<iO���\~�eK��YȤ*��7̃�	W��t��B�y7�蚾�׶YEd�ҖH�NYH,^�X�4j�����?.}��vԸ_�N�J-��W<Y�-o�FN䮏y����-w��V �9����ԃ�ӱ�5[{�M�q���y�S�fӄ��^!~��:�I>��HNӅ���G~��V�1s[�,���asǦO�/��X��ђ^n����V0HO�R����̠���U�(��m�����3sn9w�9��q��R�t>�'Q�B�Vw��W6 f%-֌���1ߧ��`N�P<����GR�0�J���iĄ���K!7�J�6����a� ��]rZ_O�`�b[��v	��cn����h�k�F��i1}�BDE�Rp�?���JәZp%Щg�Ism:��}����ճ����Y�t��k��̈�0�>Z%o'�IjƪoY$M���Ti$/V\�D6D���q���ܶ�1$�~�x��bJ�"�Y+[�{�vwGJ�h�L��;y_zR�� ��]�nK��!��_���c[�    �ʄ1*���pr�1�ϞZ�$����!v���Y��P�Sh�Ղ$<�����c$v�I�eZC5�v��V/u�cm`4o�t��������a �G��Nz���W�3D�~��t�:�	�<���zf3|d����>.�����
���˝�e2˝��&�Grs��D��7�`W9C���.m�Ԁ�G��'�	���%�$���@�\>�����i"�r�<
_�\9p��#�J�/|x(���#Z����4_��Ϸ���&~��]9��@pJ,ɢ���t������V�-�Rū8�y�����h�o�ۚ���w�v�H������r�Lb�{?K� |��h��BcPGQ�G�{{=&�?�-Ww-fNo�����}���&>~}�_�_�#_�n���QH�7�;���jm��c�\��6E�F?�pi��9�+��Z�֐B�F�M��M���x0�RxK1�uz�Y['�0G\�a9x��`�Or�䂪��BS\��2�1`�8�(�{��[=K����Y>b/�������[)�rb��DG��<@�V*�|��hTa�����z��
}��{�ݤ�U+�WN\o��s�ZӰ�,�H���Zދ�M�8u5�\k� *�WN�`� ��.I��fT�.��d���+�WNOV��P��g&>�2;�O���+���ɵyƟL��<mp���C��n��m�/�����r
7+�ּ7�	F�$�Jo-Ek���t��זr�Jl��r[͞����ѳ-F�M+�����4���ʾ��d.'t�#����R��.�H���L/М����+��%jI����n咡n6d��'u����UZ��Лj�#��[m��lEc�ίS7�w���G)�n��M��#��h�X=.�(�N3}� �����*��T��2|vd���3啒ȓ�k����.e�@|�Ƞ+i�Z-^��<�Q�fbO/B-47���>&�>�dS��s��r��$P����ߵ�}���f�܅t����UB."?���;)V�{�Ύ�8��KďJŏ[p�j�d��̸��ܭhQo����N=۳�ػU�R�G�X�+��4�q��j�w-���mrg��[<�k4�s��y^�o��/E<��肦x��'�my�Z�sh��.�J���
��R/��=θy؀���o��T=�5���N��J���S��:x������dU���c���RڪF%�.R�ܩzp�KZ�t��)�[N�'� �^r�15 w�.b|�@�=9tTt�HF\ѽ^rw����u՗I��gf�g١ۮ��~Jt'�a�B�Mn��L˕�(����T_Z�olP~��8�$��;���zRA���P|��Tk�-��y�g��?��_��?���E�3J��
C��>�#�)	�}��D6o�a�хzX�)m�l�P��7��Z�hP�\���Æ�v��z��<�.�.��CV�����^�	k2�=�
ʖBѽ�ip/��s�t4�l�p�v��z����kT2(�gm��y��;Y�;�1�v8��Z�m��^)�?�> �o�����Z;.�(�����u��0�;#
oEڐ�i;=���[�'z�{�s��.�(pn[�Np�܎sK<tP|�qDɅ�vm}8"T^�i,W�)2$ W���C`=l+ꚶ
�Ɨ��c�� ѐvf� W1[���*�v��v�*�9�i��)�Fy�{L)��8d8�{��Z�UQ�c��vI렜b*d�d�k�*��/$��\RT���p���gb�X���iONn���%��lp�5����k�r7�a6Z�[�v��5�r��p;]��8�V����E��)�5/� :%{�[c��~$d��'~����oN]6۔�-
}���ȅ��N��V_�j�'ٖ鐬3�R��꠯4	K���6�K�������� �r��X0�)��60}��Yo����Kd�sZ��~����͸��fV*HP��hjԜ�\&0c\�[�@�Cӣgn�5wJm�Y�n�0^�6ݚgް���3}?�p����H�ǖF�w�xˮx7,��}����IS�Hbh~���GȀ�t��F���O�?	n��h�֞'�b�*���tz��0I&�"����=�<` 
��²/J��� ��wV�0#���8��W:�ɬR�}%n����e����AkZ�ڴ�ťB��<pr�'��6�)�Xͭ4����Ms�/��ŕ���V�']=��k�U7	��nௗ&��\2C�|P؃¾6���8�ȧW2D�V��m���BY���ܣ��t��˯M��r�^	��W!�	}`<���C��s�gT��N�_�y��\�WZ}��צ����ii���-}mZڄ1�M�M�0��z�R�ɝj�z���%~mJ��@u�a�D�K�+.��ɖ��t����Mw/�A�ĕ��T0��p��avV��Ǩ4hv�-ΰ��mw�[gԹ�ǁ��#�Fw��]��;��s�Z���ȿ5=��B�0�J.(B���>�I���gz�$J�r�'}$@a�.��+pT���DߔD�z���bTW�hRS/��r�����$G��|����&O��{��Qn�<=~�d�k��]����{NO�4Qt�(�I�)�[���� ʁ�84(�����Q'Ŧ��dȊm�πk�-�� Y��,��|h�6���S�r�%�f7I^��lQ,��=e[�bM�Ɛu(̐�8�o;��8 tꪥ.��|�{��D��d�����R.B�f�I��y"�^)�&��9YS�N�c�7r�h���y��h�W�)��B�dվ�XV��贲?2(|�ȗDZ��Ьd�7�T�d__�d�N������k�4#[��h����P�r�C��0k�H�d�ޅ>��nyb�0�YOr�<�#q�-;>��� 5�Vv��D��a��;ZE���f�s�M~�?=�.��r [�8-���ʏx4bG5�XI?��\����� okUN��:�� Pk+W>�0C�.�Ĭb�؍5��r�����|���L����5JV2�V��������8h]~h�
2$�K�uؑ��|�x������GU$9>~ܡ�d�<�Md�+|�]'~-e@�Ѡʻ����ĵ�4=�)(J���>びܚ���Ye7��sO�4�pM�L8W�(	���?@���D�M�f�	'�o���V�Ŏ�8=��{Rф`3�73Κ��H�ZS �K��d��4&u%�j�ݫA���^�kM����L�$	�e{/���5j2�e���dI����~�6�2�_�~��0"���恚��+��r3��zv|�� x�V���Y��g'�̷�2*?+/��p�uLf3m[�4����y��j[ ̕0��b����5�[��ԜM���},fk���N��Iۉ���+��H<�$�}2���!Ϫ�}����֘�B1͓�c�=0s�d�4�����wQ>�(�M���T�3#nK(�m��"�Ղ;�t�}߰K3���<�oȲ�ky��&��Y$��Mux�~.�H�]t4�YxE!ó�ډvW�	�ஒ�훠xRH�7�����C�,'����0��TK^oUL��h�B�f�W�E��o0-
IH��oKh(� ��"�М�����<M�cQ=/��Р�|�^�P����ٜJ?�l���ip+�9r׮wb�3L�(YFZ$��n�<�e}�&r.�x��؄��^ �T�� �&�+��~�DE$G�FŚ����[8F��k�"�H��\�?�s�oKY��Vd;�p�����b/=[o��ϊ�s
����n��:�-S�i|��j�\�H>j�FN֓iy�U��h�w�I��X%p���爾�c��f��+'ɊfF��g�4 ��X2���D�������2gs���܋:�P�w���A�Q@�C=��2��JM�Ȣ�\�Uhʥ\Ѫ��-,�Կe�s�'�A	�(�5�5�T���-pǸ��1��0{�ņ�4ra�G,�4:ʿe*��E�x�3��d�<=�Y:W��^�v}��2���PR�8�01 #��/J�ИgT�`�tA� -X�\D��}�3��A    �+�h5n�ti���x��P ���wQD�N����`���%�;��&�� ����xK9M���e�H���Է���'8VJ��6s�����ӓ N�D�״��U�:ۅ�6�*�l��$��fdl0��V�[��0&Z�7X���%���ԯq6��uZܤTڶ��¶П�v���<�hp��N$ژ�8˚s�H�\r���~��H;I�G<�Aİd����K�)��_=݃TA~+��1ۄP?�AOEW[Bމ�m���^0�`�F��,��毝S�j��2E@6�K�N�h�!wF~�T%}w�<�Q����
"tj���G��Ե� ��g�αj�u���u�����u]�/96��	�2��Z���Z֔_=k��=�cr��-��,��gle�j��mo�d"=l'��Y����(�r�þ���P̉.-С6�H�أ�읍�2��.RQ�mg������}6+�O��8D?IUg�$��Z�h�{f�՛�e����K����L�U�̪�zfq#2t.,�n���	a��V�n��N_t�ͻ~��d a��ˠa�V��v;}�*����h<tn�; �Z]$�Z�0�B�Y�k_\�����*��,�
�p�=�,5��rZ��&��''�r*�*��E궟[Z녑A��֌��	m����n��b/�l���h�k]�k�/��`�q���h�Q ��r"�
�r�Ej�%�ow�>͹j_~ң���P����������7$v}Æ�5P��a��2Z�Аdfk1
�R�&��4!����ɮ�o�[�+�4s;�����=�\gT���ٗ���y�l8�"�BE*}A��&��,�l�ܧ��r���>?aQw)��*�À�d�"����3Kt�I*��W��i�p�c��F�5r1�ݒ/��������N9/8��E�� ��.�㼐S�ģ�Er��KGi��vr|��k��v�6�Ԟ��Nւ��A��]�W�V/�e�6�?KA�w�����v�W�jak���l���\`jH������d7�N*��r��7�y�-�(|�-���E'�s��I� �W.�B�x8�mB��Ƀͤ�I���D�O���Nj��v�~�mgd�6+������
�d���`�ۻ9Qɉ�bq�H2�q:�b���6�f�K��2�3O������8�I̷*�9�k�H�ki[%�d83�y��aS�����/��N��M�w7���F�H��H6����#�^#��R;9}�<@�v�WĀ�[�y�F�⤅,�6Ma��b����X�ҏt��I�Ƀa|[Z��Hڍ���M
���qF�Ov���v�;܍Z}�#�q���Gѽ���g�7� ����m6����.4;۝lX:�G42�H|�,C'цd��Z��,���� t��[=IH%��6M���A.6	k���7*�[�e����!� 4���}1
n� �El�(j��7J��[g�Ml�Uv�h�<O{�X>y�t~�k�qC��ˮ���C�֡�@$�p����$���Z�\h��M��8u�7ΘF?r����,�xHE�B�*H/;:>)��x6>�=	vs��Q�!���!�����������}2 �m��Z�v�R�w�(4C�{� z�8"tH,s��Υ׫�_�p��C2
i	t��$>hp͍�����G��b;����9-�"k�.�!o��DS���dNR �:s�v�v��*���]<���=J��{^�I��  �<�.��D�<��I�4���r��~�[�[��j峓\�8\@��݅���G!Qr��!����>�����zM��>~g(�([Ȓ�n2W8d�4!�����^���I�׿CNd�d�3WWb+%]�ז
|��C�%N�7����V���ߝ^�"��t��G�C<b��`���<�ĕK>,��`����L2����������o�ŋ�Tk��ۜH�Ozy��פ����f���"�ӳ����U驻�˥Fɉ�ǀ�E=(�w��V���h���v�-;��$�D�O�|����ܞ�֊�4�������"�}U9>��A��3u���p�i�1O�݋��g�Z�ժT?���g%�����0����ـ	IX�ݺ�Z�䠰�����S�������Y�dU��rS�V����ɻ��x/��ų
�H_|�c��|���Dc� ���Cgs	���A������Y�t�~�:v��.�f��,pN�6+9��rmA�t��f���+"�T�zP��.`k���j]|!�<����e(u�f�%�v��.�a��+�B�
�X:#��V�c��D���f��v�����Ww�����N�଼�uE��h��5]6��ێ�o�#1�d�q��G�r�U�l#�P|���@/De�A����܈h�����������3-��ZN�D�$A�xrV(��?11�S�zcwG*�7N�E������ռ�t���q�ޙ��7����7Nѭ,uJ����	v���U�H�(dF��i�wÎh��.z�9������V۹�'�r��d���o���_֠$o�w�t9
�7�,�&{���m5��q�N��{�;����� � MzO_G� {�^V�j�M	�q�.��Rz��t�����&�G4�dKN{�Q���cԚ��G�m�(l���P�5g:m~�O")F�a� �P�V0���*�R��E$�L��/�	�f��ٚ N�29
������B�)TO��$�U
ۺ��j��vN�����$f9�\���Oor.f^�����+#�&K�sf��}�L���|[�K�j�w�%Z�����(X��5\��A�?e}OI��)�6 �O淕��i ��{����]L{��Vzg�����9_&��,'fAň�E�9�XM��P}�(�XYcw����s)E�IMI�A��YY��O�����N�x�����Q�E�:��[�P�lv"+����E�c�4�ΦXV��/�1k����-yGk�@,�t��mxy�~@-�E0�s>ޱ�PT+��r�9�$��o&����}	P@��e͏*t)�����y(����`T$}#-VM���\!���ٲ��N-�!��2�Ө�z^p��r�=�ݿs;�o�#���N���9#�9>�Xm�{���~���>$�j��k�G�\^ҧ���޷B�sG�fG��.y��GG��"���Jƞ^�?���ZϤ���2R��,m��pM*����}����_WG����@"���4�r=�EٖO��\�����Ek�����\>+�d�C������(�T;9����ӧ����M)�y.^�L�a�{�48�2s�":Uĥ4�d7e��tr֩V>0��)���*� ���	5�Tx�w�G����j�++�)cl3`j��~-��7f�|�d��ŸxJ���9J�v���&vR��V�7��z�3CGElq��'Wp�Vz��9N^y�G>�L�A�6u�G�\r��\>�e����E�尋�8�?<*5K�#O�]��b����\�|E�����g�$��h9�l��%j�|2�wY�^c��}�"�\�\.��ݣ�S�+�%?�Im����$����n"=�S��G��mO�k��(�\1`��C%}�K�2N��s�R�?P�P��Ȁ��_ҝ�<Tz�v����W�_�لr��CL���y�^�(Ҥo"TO����9B9��V��8�k]6��Ƶ�}䚫�3��L��[�	7ʧ7��4�{Î�5m�_VnlU?�GFQ�G�Yi���n�H����6y�d��uƩ�u��p�ُ��ѣ�]@	��':��f��������R#Yj�,"l_ƴ�]�RT��+�H=���EkՂ���r�J첥�D������bIK����Un�ޜ[���fb�6=&4VgG������z7t�B�oܳ5K�i�L��E����Mɶ�I�:�5�z+6++��p�߈��	�a�Bz��3e���߿��j�C��s���=���s����P���gYp�U1݅�17�3�{��-b�M|M�J��I$N��]�G[�o�=T�g�bp[Kl��z��5C�`8a�����@�-���    V2�&7[W�~��I7&����Pn!rG>��)j ⸆��g����B�ԐLy�ԧ~v`�Zh��e���#{ƒ���F����<�z�����U���|X�p��gD�P�%����ȀPhO֓>-`�b����ǅ�BY9Wtqs�ɐ���$ܦCS���IQ�1C�%�;�۵Qp'����F�aStF&�1qˌ�����di�t ��[����鴘$31�ri�'��@��Es�@����2RS�6���%v�>-���P�N���	�N4�,B�u�`��-s�7�,b_�8�1
�I�î|���e�M.,F_�k1�rZ- ���D���P}� ѯC3!Rq��ݏ@��½l�GJ�{ڧ�I�����5���	�BL�$T��n.t��9�=��>MP�j��91��,�*�7�F�݈Q��˟���WO["�u��@Β���͒����I2@�Ҟ]t3�Vr���/���R~��5����h��#�����xR)�Y�D�'�N�wG	b_�A��L�rZ;����waPr=�5����5 +I�/ܒ�p+%DY�RÓ�!�B\4�V��Ǚ�!��B�Q�^Lњx�b=%�E�k�-�8⚢9M�Sr|Z�U������߅��ٚ�{���ɚ��:�<��ǧ������4n,�|V[/�-��Of�q3���S���$=�y���T�0���H�z�id�P�~! �H.!�y9�,TX�p��ِ+�&!��2��Ȇ�>��)cšN�Њa�J��`�\岔T
����\����P�=��\/a��ӳ���z�K�x-�@��	p�$���.����b*�|����(2Sm�'L�Y����LK)��i��Z�4��(|(�%dv�e@�\#5�&�)���i�t]_��v�8���9O��������Ɂ�5�ɴ|�m6��������_���g����i�Z�s�����D4h�kr*PtV�znu����m���s���w�6Q�Y� ��Z(W��g^Im�nw.�Kᮗ+��8#�ݘ���}_�1w��h��q�{.&!0��L�P��	�d.9��z�Z\���IN���Y��v:��$�ԤQ��g'������s$�x��b[�I�����H&�K���3F�J�0��n��f��>K)gT���k��cq?{o�����@�UHno&Q:�P��x�:`�'6x��42�-g�\�u"�&� ���
�;j��2 0��R���2>��|޷"2�^F+��{zNd��EL����M���lX�aΜ�_�C5���;5���T>���E�������I&q)��>3 ����IM$�X.���Ijt���&�)23������䢫�D6�ɧ^�:m�6]�գ�e)��J^�.��(�:��%�q-*K�Y��M�S��73��wE��YH�;1�״R=����D�)5C��X�f�i�l�K���#��L���Wƣ��'
��n�M��ۛ<���+�e��$�)��j���^$�5-�����7�,
Z�g�Z�\��WFb�>�>Ϯ.�zqB�� �hY��2w���=rr�Ǟ���!���B�(����<�x���*�M�0ˇ��X,=����+�'�G�,'�_w���p�����)#��W�F'@����R��+��Ś*u�')�d�,h�}�~�)}���\��y啑�7_iC��3Y}y��L�A�r�4s�1�ؗ���Ph�삄��2}ѓ�f�E�$��g�x��~�z�/�����&I��5
�*��N�Zjs���.|C��b�I��;:�ME�f&QK�=[v/�G�B��-t���.v!�ZN���<�~�|���ۺ�N�C��#'�2�m�Yм��C&�4�)��<tl�k��0��_)�����c���x���5�G�c���f�g�����C0��@c-<�OP�p���	"�خF�^����L��r�P� ��K��G��'�>��s^�oA4�;�l��24��{M<B�*�e���4�"m��%<F�=/Xމ�
˅��+lM� ��K�8�oǣ���������}~���7�s�����
��d� �l�J��'� ���S_&�,���*���Y�%��0	��3K�B�9���Jټ��Ih*'(%�gp&zS>c&^\&1���P�O�[�æ���X$��>�X��'k9h�s����N�.<�g� s�ˇ\�r~���r�锬N�V/�NMw��7�4�}����|MO��f$�^�>����cM���)������������42hD.϶��I�xr*
�6�v�׏���#�&�9ԔO�B=I?�l'����+=�C���_I$�
%&_�a��ר�D�ZOi�p	d�|K�mVf�+��+ꕧph+C�A�[�[p�L4�kq�����Js�w��Z��<�oi�R�CwLN��"U�mhf��_�[|2Y��f1<a�?��KMée]y�Y�S�,�r���^�������}�\�)N�	���ρ����d�O��7+a����\�a��2ZP��+r��vF��a��	�W�\Hr�0@kr�fS�%Y�J;Vp�
�)RlQ�C�m�xѤ�;9]��N��1�Egкu���w�|sx��g�����p�տ�/��fh��0����28@`�4�r��Z�0��?� �Q�m.�@�O��ҟ�.�:C������Y�u��o�:7���{��F�d]l����N�]C�C��D�Hⷑ`��j �� ��!�͘�7�F�L�\�Rk���y�y�瑙HTU��s��d��.H$2<<<�=ܿo�ϡ�h!<���p誆���ZS��y1_�gos �@�zE:ثZO�g�<�}���|�R�Ta]j��6.�����sFճZ�iY�4���8[�{m��r�W�u��1�Gr�K�޸��L�;b��E��;j*�l�K�S?[�E�`|���v���h� �Qq�j1���ft=k*�\Fd+�`PD�(+q�W/IJ���}ɴ`�Y��b���v]��h�|��q�<��}X�]�{�	�;vG}g�}tE��wcW�\н{����F?��s���	��Ԣ�'�E?�۪�-e?�?$u�5�Ѐl�{7��7�2���N���d-$$<$Js}eSM�/+���`X�P%;��C��{� ��d��������n^��yA�j'���ѓ��Z�TG뼕��4���޴�6�vB�g�ޥ��"�fl^�RҴD�д.��Ƅ�6��-����1�=���ٍ���Ӗ����eF-�?�q��?+ڦ��o�D��Hc�(i|wX�JS���n�ֆq7�H#�0�f�����-�l��0V��|�ue"�� �CI
^��CyEG���{F@��3����(��2�]9����U�-�V����@�����'�
��Є�TM�s+���O�X[�j0t4�~���Ϩ�K/b?�z�� ���W�	��"|;�Q�Nvb�����>��Ԑ�mP�C��H}2�f���?���,�wu�[>d�&4�1����P���xEN�jU���j _��*�;����t�8���on�ñQL���I�/�ֽӿuF=����?m��G-�QFN>ET#
��L�$/�6�*�l���Tr+&�$�c.��-��-��7�g��,R������g/}�3B`����%:�k�2Xg%ZQ��/��.�a�Y��K1��k�l��E�+�;N�B�R���Fa2xz��|�=��}K��t!��*ԏ4����E�~N�+O��ek��y�I��zU�/R`��$��LX�P�{o��.�܎ނ��˝�����j�,����*L*����[կ��Z>��:T���-��G'WX��������;%�"z���ɲ�����-�쮨��T�������7�����[LԽ�r�G�m�v���t��>؃�%C.U?���	�/~���Ĝ��{�CwS�z�R�d��>�0��Z���=c>��	�,[vI�)���D�+pM����u��~r@��3�	��֮�:��|��P�+K�GG�������}w(�    w��U�=���iN��-�����'y�~E�sR�$���T%5^��^��IV̣�����:~*��\�G���{F�O䯚J
��^Z3�6s���΂\��n�8yŹCS�fA��)k�G�y��ǻ�}�so&�j�����	��c�YcS��!G'��34C������?ɗ�����h�P��KN�ߣ^�҇���Mz�\*g��S�a/ϡ}��N�b�o����Ys	��&��ڇ�O7&�vL;��TƲ���yTst�����$�j*p��Y��4o�zբ_�(��O����R��U�8'���`���\��	mG
��dp:�_Nć�}?A���ך��3�&��(N�������;���(�㲛�����bJ��&p}3�aJ�>k�	~�bL4dH���<X(�@�8>:=8�A�\[6�hvy/YJMO(�������$�Ogd���3��ȣo�����H�{Tm=>��c�����E��kq�E�7����=Fw��� *�D�_�E�t�~�3�����!�P�ԝ����}����/����b�V'N�v�j��^ão-���-�=�Tp��D���r����N�w��}[�?� �>z��v5��
	z�C��9>�i�N�_ãok���C�zc�p:��:cU����ՠ��� �jmǏ�vj�S�����j����a�ײǝ��w����ѷշ-�l�F-3�	a���\�E\���\�i�tr|�S�*��G�V��zƷ��W��e��܋�	��ӝ��t�5<���v�ZN��G
{f8�!��Q�5�x�D��l��;5~���g�/^�_	XDJ%`��e��5�|��;~���?�*��˫V��o�F��#.j7n�{W��}tG�7~Noп�ݍ3�r������4�1���TG��[�AЗ㇡�ԩ��}�|#�����Ӱ�]{nK݇�`4l����0r���:u����֋�E�h�SsZ�(�^�k�̀����]j�f���M��{�e���L:�tJ7�_���L�ghڲ�VԦhLG�5IF�=��b�������������_>\�\��Qӻ�ʄ륉�W�N� #�Y���1Y�Z\rA�+E󌺡JDrr�N��Af�(�"A�������W�]s�(]x\����;5<"36��6�! ��^��֯�_T�6譧'����Ab<\�,��Jx����R�d
v1|18n��fI������`3���3І(�7��:o�Ƈ�� ����o	�+!ؕq]�)^�������0����;���"����N������q�H�O*��stGO�@YA��䘥لܴ�^���UL�^&K[�����H��r35��I�2�bX��u�Z1푸5�Ьy�hlφ�Fk�x��6��:^g��r�N����4�j�WIZ�w�oT���z��Р&e	�������:M1�$���n7��{�4[f�Es��u9;\ҭ;@_�ῷ*��V4�/����&�[d,/�x��άRurr�N���,b&��
�+5�����-�J*��o���"G�$�~
�� 6�����2�ٕ@���;�� ��XC��s%�?�?�熧`��@��| CQ��"���gVT�óU�B��	99��[��4��F�>Xt�T ��VR��
P�O�+����[
>���~�$n? )�^�ǘ�]z�;�;��Y3n2�~�a *���{�v������8[�����$�}�j�[����� ��.ݑዜ���/j=�w�N[�n�;#4l�$	�/����ù����������x��ݿ�����ۦKo��3}�����yB�"Q���m�8^Y��U��8�u�y5.�OJ"].���#�v�Y��}8BSy+�^�-�݃S��0�y?�(ĥ��������-�����;O�o�@��@y̱]�V�O��h�l��A�mg�,(3NO���p{f�\��I��������-M.m(4�Օk��ӓ�7ܟ����9���o��i�Gɀ^��ܡ]��v�33�wi0@�k�uĵ�#3tZ���t#Gx��]߳�{@��8��i�.6]9�H�U&���|�m�!=-y"��t�E���_)\��S`� Y}(�P\��� Dw�-��@?T��N�k�6�i��t�N��8�'H�َ'J�ɐyC۝ٳ|V��C����g|y�� ñ�˂�x)0���A��'��.I
�:fa~�,��Ҩ����F�[��6�fS�y��do=O/v��Jf'�X A�5��y����n�^�!̓��2s���Qf�ph*Z�)^��H�j���n�^���NՊA�u�r��	���fCuszv����1m<1�����̼��qb�/
�_�Z�c���ֳ��;gǻ�zsU�}���d79�crȉ��@]�l�Yŧ��ޤ*n��n�^��y�d�J����nr^��l��`���C��ל���|��;z1v|��]�r��?����x}_�-�r��.�Z�u�y׹c���Ki:o��E��_@�X&8��������<�a��BoY�丹�&��,�$�cKfiOI*N�{��-W+zG�b�k�1�B����g�� �) 'H�j�X��D�JIE�"Qd"<a]Ԯ���g�"�Qa����Ƙ�Q�A�(�@�!E��	�{����w�nb;I�J��4���~WT��jnB��O�֕�����$  !y��A	4^�]eF �ŅY��b��.TL����$���+�L��·�HΡ&�����6�BU�B�2��k��%r6����R��2��W6��wjE�0��L�+$�&���3 BOR=�zM/�4�0â��b{�k�;��p4�9Z>?�A�}w4vh4��� ��^���h|-��u�6��C��s��n�Zx߹�kΙ{LM��N�ο����@�����x�o�a8�+���W�o�~\� ������M��,��x���*����L��hO2?��l�HN�
���\f�y����|gD�w��p4�]���t���˶�j^e�%�ߺ��# �w�AtFM+��B�X��	�/{��������O�����y��O�h�\�G����5v�pD��?�{=S�}�a%	y�:Y�C��z�.�I��N�u��wM�2m�M���p┶�n�A)��P���ˬ�e���툪vfp�l:����<��Ql	^�q������2�& \ə7tѣ�+?h�#=M][/ie��4kqq�v���䐢̨)3:��}��A�v'��_��h��!n�=v����0/U�S̡�p�0���/�Y�Ƒ�PL��SgjO�K�@p����l� Erd�*�f���|N8��B����^�k��ٚa<�:
`i�iT���(��_��/���H��1��Z	�w즱d>�!}<��'0�*':��K0g}�FQ�G���\C��u��]w|7�����=�?���]q�*���h:�< I9-gLb�vɣ���#o0�kݾs5�W�s/�w=�8.��.��+w�'ǥ�		���O�"x����?v0� �_`b��N$����o��	ћȈ�c\\��$�bs�sqRkZ�B�x#ABC�Ƅ<-x��g
�Џ�]�썠f�Rt:����se��c�QKx�ufȏ>f�����a�S���zoq�����=䙥Ґ�C(�\:"h����i�0H�(DZ3�D�HaŘ�G�85��_>5�ڶd6��I���+/x�8�=�Q�o���@�{��j�4@�`N�/���n(*�"��0�L6�3?V��E0����ueF�H��k�!�e6�s�}�8�ݥ:,z��m[J�Y�����6Hpv�[��,Yp^`j ~N���v`�u�h���Ul�9)6�3{�#�IC�k0���gz�.��i�P��G��C�������>��Ā��{��l��Y�w�M�ЦD�J1^4&v�ը�m��4~"!A�6�--�7#����y�?��H�M��^.���fjE{6Ɣ�H�w��F��N�"w��1��s!c�+Q,d�&F��G�Ms����    ۑ�˄�e��\���\1z�d���Δ@rӒF1�Mi��
g�a���_�
�a���HϹ[ft� �G��V¥� �U�NL�5X!������=#3��l0���iO.Lj6;�rvoe�-�vA����
�Z�e܂�n�	f�2���n!|��ֲ���ّ
�S8�2����P��<Sp����L �ΰއg�z�g�~H+b0v3����9��>��>|;�&s��Л{�Z�?�C�jY�}�˓ߖ���@hJ:gv)9��/3�g⼙Q�QR�ߑϒ���>T4,������#M`3�F?RGC~��cri�Un+��V`� e�l�"L���~���6Y��x�q�GX��=
z_�Y���)5U d�
Ծ
�C>�yfJ�
D��f}b���i(C�a������X�k�-��V>����(��<dȷ��@�(3`��ޒ�3?�� ��N)�T:Y06�XE�۽N$�q1�G)h$>Y�3��q���+s&��U��n�$���-4�&��_���2 `o�7��9��o���ޱ&��!ȢSh�`�k�q�bl@�8�i��vvp�]c��Gi�D8�P6����vG/�O���=�m���yNU�b��P�J+�Evp�]�(�rf��^ӵ��3{�Wvw�����I�JńQͅ�RSm�ݵkpTǓ,�"����d�Wr��(��BU��w-Ԝ%�Qp������?��Y�B�L�n��|��������=�f����5�C�sWc.۾���y[rq�gK�׹�`�+�E,aZ�Y��fQ
t���L���� b[�������Zv�J�����������8#U"�Jp�R����*!/qO,$���$k���	�i�o/���@:&���HWs�����gM_�\�!>o�8כ�;�G:�Y�$�ut�3v %��x�	m.���L�v�ڝ���μmZ/�Ҧ��ve$%�s+�i����2�[@1�=����Ǘ�x=�*a�E��6�f�t��X�^��3�J.�en*�!� ��J��jh���2����.U� ��1�K쬪H�Q���4r��1����4Q�|��@-U*���d�����p��9��u�9�|'R��`�Y�3�,Dm�U:Q��*� �$.�2^��M�b9]�g-[-�/���#�Z@��_��"Cϧ�yn���4B�B\�K��N�]g��`x�M�C�_�~Y�N����y�!9��_󂯈>�+�s��/iߋ�C&�&�1"賞]
�v�M�c3�Q�,)��<<�V����zU-��^�L}Q>�W-V��25�p2y��_�K���
�ʂ���_��e�ָ����jq�G_��7��!��
���q<�m��o=�ρ��w����nEn���7�!�� ?�̦��"v���Y�?��{�Ֆ^�H�I7�~t���Z��_G:=bL�fl��_\q	��"Gv���Wܚ,�r^~4!S�Z�wx�[�U�WAWg-����q�ғIȅ���NVղMG��ac��;�˪流�|�$��=	zA�}�%߶qʅgGG5���r�m��H�ʪ$�+r������>Ji�`���*�	����� ����4T	�R�,��
59�4����۹ܩ�̲ Xo��tl��<׆��g�:���zr9�������~��>m��������"X�%&�������4kM��撵Rk�ޗ�?�S���+�Kgg�*���G�޷~Io8=z����p|���<q��S ���Fyq��������ϖ��q���N���L��'�"���Q�J-z���1����.���ق��V/[t��rDU�}���;���mv+CM�����b���b �[��;�g�p��w���3��)Ya�ýi�Kqu|���f��vkd�F�����t��������z��oY��`�E��S�Ó�f�4�-k��&�s�22i�L�k4x�5��������ӝ����-�}�{�"�ky��|��oY˛��Nk�̐3d�����V+>L:>��~�S����aU��ʕ���l�-w�\ǆ�&ϳ\��Ë]Z��J���z6�(����������ǲ���TūX�eSK���y��jJ�4y��M�k�MpG�Y��f�.�j� ����*��O�
mF�����m\��ҊN1����k�>Ӯ`�RK�됼�������|(�8axu�
�,��1N2���a��o������&��g3g.�\Le��AٕY.&e�
\ .s���i�����ň�]�4���f���Ֆ!?0_��
W�������~�U�B���$�CwZ�p��6�>vm�@ GuN�P)�8��ܑ{c�M��r��h�9c�g����v��xN�`��<��ޭ�gX�a�Є�	'�������v؍���>Et�A21��nI�F�rL�q#�$Tqu/9�)�o�x^�چR���0~pS�F(х���-� ���(��
���Wҷ�U�G'���Ͷ�m_.Q�LM\����m:h
W�c� .)*J��~-��LITzr���t7���'����	���)K
�{a��/=v��qC|�T��rG�F�U�� �v��ۅ[\YPL�*eL3��h8)廽*���r��r�U�G�Ν�D�{��y��@�EMJ�@k\�2ƃ@TG�XE����Z�X?�6o`%]���CO8���f�6�;ۧ�F���pt,���?L\�<HU�@(��f���=�����^t�����À��:�$��<��q�;{!C�5j"> n����8%faĭu���W~[\�d0�J����3�J;�K*�U/-�/(��6�ڴ%y����T>A"�/���5M*v��!��`m�3`(�[hRS�Jf!k�eG��ǀ�o�+88Ǎ?Ft�[#x8+��E܈�����`k����X4��t���1C�6J{�_3M��%��U`'_&}�Ƶ�jI�\��Ɂ�4:~�_��?&U�D�b-X����?f�y�zf�E{���I+zdmn��ʹ��67J-0ږ�j�na���Q����fD!Z�m�Գ��=�c�� �����P�=�-�=1�&< �(�/��Ĵ�RD����W! %�d�!��S,�c�@ҒXN�88�Z)�5�<D�=h���|N��]h�x�Q��/7��r�n�yXҗ/�S�{�eO/5,�ѺR{|��Ym3S�+,T3�u�����1��+?>��\�RO��\g�����EO��t�%IX�qլ��<p�w�h�-�&!PU=tG Xſ-g̰�C@Է�.���w䉱;j;-g(�*�(��w[����+w��8�����D�#��Ii,]k_��?fj��d���?e��)�����_;�c�̹�kfq��HA���_��gD�&}��KR���c���-ޫ8{��Ed��7B�5����kDz��Ȑ'U����{aa�z2X����{��,a�S��������e{z��89|/RA4�+� 
.�l�-rX{�yrT��-�l�)�Ħ|�.�_t���>ݍ��!�
�<8�p����G��&>��C\>�n#����S\��jg���&*�0Nz�q`�<&���j��c��ݺ88<>AH��v�'���֯�Y� Y_�'>Kү�_�������F���"�H�3f��8Ѝ�t��5�ݘ<��S��w;9�)��}�7���"�R�0q��:�X1�_Y�W�4伾�C(T� �$�Q"��pU� �L ��} #��n�2K�D��e \&y�ty  .b�RDf���E6�Ov���>�]�-�6ql�2I,���<9ݩ��}�7�z�?:P֫;ͳ'g;�{���f5���P��W��N�^ﳾYm��:)��͒p�5,S޾%O0��@�� #�JM����(�-�;��)��}�7��-E!Ƀ��H���� ?�T�SQ�䔇�}�^{��_��l��Ӄ����g}����L���=>����.~�ة��}�7�z��Q��Y-� �#��jzo�U��*x�S����oV�l�Ae�zcm^Ā���wT��A�{��p�-q�vF�84��w�̾7n�����/�.kڏ�|��ö3    v��.wM��}ں�z4�	�uEۻi�/z���n�c�������=�w
g�:>~�!g�w��f�m���ϙ9�� *����҉ia1q�<3�����,ߔY\�l6 2��QYB=��D<��m-�׻&���yMcR�DĊ��4K,Ç�\QN��
�Wt�i��#W�M{20׳� ѣɘ�ɓ!׽.����+�&�,�o}I�L��%]����'.�T����o����7Yq��W.[[��'��L��,i�p��D�
gW��!i�;������ˢ�wd���c��"�b&����OO�?��*TS�����|�쐤�YGS���8���	V��1�YO0�%� ��,�zI�����Vi�y�0�憋�����А�a&;�y��-�il�O:m���L�R�ܣ�e�JO4mМ��Ӌ��E�A��
��MFGǠ�%�4�?d�*0�]ҧ7d�b��^R(פ�/Ic[G��"��}�S ��z���!�_�P]��c��V���k|Z���ת����Z�|uKZ���02q/y�c2�d�S�x���ځ��x�?a�O�)a� ��������:A�=Y�8ПM� �bI�ak����u�9$@��������h����p��M
P�|��B��HPp����taH�@�4dEt���y��L."=�qN��|Rn+��fn�Pkr9�t�-��D��(��ۦ��%Xc�bf�j]�d���^����~w����T��g��O�>�^{�|뗭󫣠2�׀T�(���*��m�����'�!,��)�s<��N��&f7���ye��GlRYεq��gr���$�:M����
gG5Ԣ�����^wwc����1v�z�}��� U��#�}�|t��6��W��.�w-Ԥv�������c��6rG$����H��'��-����
��0�3�E�i$mͱm�[�����퐤Y4 �6�U")P������k�s\���T-"���]P��s�#��$��eg��ZxM+��L��Bɔ��P��ކ�4}(���� �w/c�X�ɻR_��/��'
�f�@ C����T�����]�e�(f��j�$���٪�ZһK���y����<��q�}Ew�޵��6K�p�R������|��q��ag�Z(-��b9lق,.6����BS>�]�͓����F'��M���w�q�/�R�SA��It�8?x�bE?[<!��P$�;o�*ɨ�`�y|�ɵ�����R�v���M�O��Z�ʩ�T�o燴B'8�J��]��=���bY�8]
�"㣣H�)�__Q*�hp�S'p����Dp��`X���|���e�z���ؖ'�<@'��tTCT�?E"�����G��"�9V(9u� -�tJ��W8�k����d��?l�;.1R�)O��S���S�㯹��1�S���r�yn�����.�,�%���i�[I?f*��ER��a}�, mq�Y�A���+�7���_��H�~�+`�_u{Lj�@�A�H�f�O���k�Y�0.��,���+H�O!: ��R���'=�OZ�g����2�da��}�l
�'&� �;s� O�g�p�9m�0YO�2��ç��J�4���	ᣎ�p�%"e������m��ڴ�LY�Xn. 4�N�Bg���Kr-p�������:����8@-�J���W(���p����6��o�����V͙ŚbnfO�x6V|�X���ܮu���@��XI��ByԜ�/y�q�,]4^�0F���2(��e�g��W��g��ˉ
sϽ#�E��6��3	w��d�� w���SQ��dF҉��}�{$a�lF�p�� ,���oF�Ú�hϿ���&��ٗ��W_q,	��]��߸��š����:];����8���6�}A��?�lS|Q�=�[�?���	I�M*@����l&���\��O�'�$�ҡ���n�-4�6��hgJ�l* �$�o2p^E�m�	��c2`ќ�^^% >z
��O �fA޸s����aT�T_�`���ޠ用ek�V�Y�v��O��
��}�un�{e����f�%N8W��X�i�	WfIa(	,'�\K!�����A�K���L4N6�X��yA-U9<�S�Xf���f����A�#�QN�~j��/���ǐB��@����w�����_Y'��xn���$?�?�&J4C?��������?���`�@S��G�I��'��� �ʍ�@�½������y5O�H��)N�m���w�����3M�x&V�����F&��/Jn�i1R+�@�m=�49��clT��XQ�I�<)�|���+w�iG:��r\W���u�z���(�ɔ;ӂ{��
b.H"�*l	��B=�(�����,|Y��>QI��t5?R3����%ݶ_!=���x}���B���{�"3�_���@��n$Uy�����yi�/s�4�≉�-��������v�ѭ#��}��y����3�������ǿ��k��`��	���(���;�錼����^�Y.:.�+������P����%�\2�|���OQ����Z�����aUi�L\\����E8T��Hi����	�l�^8p�C��&J&)7�~MM���U�a���I嘆 �5�OE\���'Q-T�$K,hh�g��&�,���L�g M��lN<�ɢ�����4er���T�gV��E���:4�' gr�1���65"lhkO�-��/R��2�Q��D�$6�S\�eO@�&�4���y�཈� �ň�%q��ۙ��$HL�H�f�L��Z!ةW,U��^D�#uy�|�Y��(�~�I�I]�,�/
�@�Ǟ�z������ۚ�s+���"�!W4l�!ڏ�?�k�0Q�ł��J�2�V������e;+����T�7p���"'i�B�L�[X�獣�"]������xͷ.��r��ڐ�YJ�����m����"��� �	eWY�'/�Hqb
�L�j�i�j�+���f�ٱ��,���{Cq�ԞA�U[E䋧�]�Ji�y���L��
`{�sz"�:� ���vin�auD	0�ɣ�]����4N+�IZt�s�����'5/���IRN��ng���Æ�$��r�`((�V
�{/lx����9�GW"��{�X�7�C�0��
)�Lqtl�PE\��/��!d���2�oC�S�+�U�ꅮE�CM�\j�tRN�ep��W���/��V6�+�u�9Yr`ciq�;:b�	y=�\s����06��V�g�O�-�#<��\�G6M����4=���6�����q��Գ+���'f�k�锞��ͫ��z�pO��h��l-Gт����-O���߸x��Ə��&�i�<:�`�q��E�">�r�G��H�nȷ��;<x2�,Uu(�OjC�Df"�Z$��+R�)݀����6R2�6.u�m�m�aB�?�gs�%��(>mǊ�ɟ,�K�1�|�2a�X���E@¥�DK�n�f�ܮTz�w'�/�����OZg�Z��cl�z�=����������P�.il�<�c�P]��q6]0�89����R�����'�ʆ��lKMub�?B�1|Ҁ�(�����������"9<����7�ب��-�ˮm�MOM̃xo�Ԗ�?�98(���(r���.ւkl�-�,�� X�I� SA�ٜ!V2�쉑Ly�A>�p�UT��i��Rճ���������d]�9��(
�]�+�A�5���m�A�:��goj����\�zb�x�������L�lv�� ��Ң�����oj��Y��b�Q}��,���9��4P�����Ë77��ß�YM���9]������U�5�⹶���~VMO�-a)?e��bUg��u�ٞ^���G��9p��UH�	�5;�TkT�֦�����	|���T��z���p��V��V�*|�wɔ��D�F�>�쯙d�ЛX�Ǒhn���Ny�V�d��]��#[�5���w�h*@g�hM䦂��4GG�s�[�1BG�5g��m��ZR��5%j�_X��Z��q�
LD��̬l%��8���@�    �>�g&V5gR��ߠ�m�WGA�-�����1\aS~�y�*gp�����=`)F\0	"�&ͬ�� (�i���ZD�p�Z����=1x\�X|�oeA�H!��� �}���o�R&!�ț� �?��=M����h�濍�6�m�4N�-��X���k�r�5���D\±�j��N�vZ�+��vJ�"@�X%:�)�N�~��24K���+���^,~j������k�X�V�zf�8r�^�0R'�u��Go���5����08��٥�����,��?�kU�+E�����8���;�h��_�ލ��ZߛN�����#)C�����ׇ�y��[�|u�����#�)5k?�������m}�#z~t�[J���k�RǬ�RJ��u�%l����N�v:��u
��=n���"�e���<����`�\;������z�R�M�縱ӣ��Z=�`S ���:���c��,")�Or��B��,�������hJ��������W>KQ��z�_�$�Z��- sB-n��$��u*�mWE�yf4s5�K.���/4���d+ү>�A��]���2�w�H'��_��C.�-����,��A�A�t�,�E�YȀ���]Xv|��D�߇ߌC�֭� ~���G�Ili�X�z/�mh�AXnb�ߙ0
��[� 9�d��^��@.�����]U2'�L2�Zȥ�]W�A�O�� �:\�E�X��������-a*��QM�g�;�2����H�����-w�@w�����إ��w�W��|WF-w$�q�x�w{�W���n�p�]�^���ޕ���r��+�1 ��7r��PM�RM�5���V �zr�V�A#����w��^U,_H�����7ud:�G��?w��:�3�&�^���#�N@H��%pr�sH8�fj��MG��Q�%�h���ŵ\h��D�a��4�I�=��; 7͔�mr�W�]p᧨5M��l%��>��v�;9|����SD����� ��*Y�Ne]&t�5%øn�gN�ޣlʵԒ�&��K��G��mr^wr�p����Z�$�B9�U�	���=���
27�[�`Be�߫~Z�[q�	-ONߣD�mSZi;c���'3_
IgO�����zs���R��~�6����6pε�Ռq��xǱ����{��f��D�S�_R2��FH�	p]]M��������m���t��C�S�t�1�b�}z�m���4j:z��Zn�t�'�Z��#cw��-WШo���9��Z;+���{��֤��B^��,fޭ1So�Z������90I���k�j�b$�R�D
�&KRma}Ff�տ��E(�Z���5���.�ƀ7�,�4�5�j�iQF4�g�Wr��g4#k�a==?m���������sM6�d�D+Pqf}z���/�_��q�̀���~���)g�,#��>�>��Z�~==ډ��y�5w�92�j����s@4V�-��zaH���9^�;̉c�j��:N��]���G�C���@ ����5c��r����������C��Z�3�N�_H.�ό#Q��zd�L>���#=],e�(��d'�_�N�c���-�D���y�ï3�E.L*�L�cb��{�ZB�'��J���;��"�{%�9��}�� �re�$�Q�?x�n�G#�r����)#Zf����y�42ٰ�k^�CFׅ�Z�ږ��ط�vs��
Z[l�%�4T'�9JA�<k%j�'�J|�]=�f3ͼ�C�����Y�� h�+�T��/33����5�G��4P��d��Y夀6�<ŝ���ArV�2����h��4����\�*}1�"aTp����Q�:K.s�J���!���n�
T2�[�����D 8�|`�M�ЅC��VN�D-$���_D����`o�'���>�1$�Lq�MS����#?/�����t�`V/�jx��,L�mG[g߉�ڒᨮ����.ѳ�w2�o�LE%|9�n*7��T�����Ķ>��<�Q�rYH�b����~!o�U1}'b�&��6H�����;�ٖ8*��G�4�u$�B��RqZ��C���_����a xf\"# �{(v#�eF���Dve�z-]�E`7�l��@QV_	v�q�|y��<��`��ϥ{����|7�Z�"Yћ�J.�{5�=Ac�qB��4� -���h��+��g��){S�Z�5�޾Va�C��x��dd/���f�����v��:f�C���bj��9�0N(܈�<��\��ŽGTLF���fF��N� <�I��yMBtp���	Q�Û+�DP.�
���Y�E���@�=_p�p�BIZ �i��-�Uo����C�=�@Ømz��~�O�`bZ�&��4kڢ*��� ��{��Lxᒳȱ��/l�5w��ԂsCE
�(9��S��f�az���<��Ik(�^�f��J>�t������C�f�|f�2��Ba�@I +�ʩ�P��̙ �|泌~`�Izzz�J���߷��d
��};�\�+�{,X��J5���=�g�揸9�۹C�*X\��{CKIrР�d�vǮm+�zu��$�O�K�O0�Ex �IO�(�EE\�߻���O;&�v�����}}I��7�V����i��F�����$T��smh�Ώv���\;�x�6ʖJ�$R����F����� �,�ej3��YI[V�R@3�������T�I�Ô�#���X����ܚ�c���S
/�y�Fk�a�o+6f)�Al�MTb09���y58�b�ů��O�wy߫I�Ҥ!�$�V�b_r���01���rR�5����Zܗ#����u�d���{~K�EB*J�`u�.���M<����?�*�����.�j�R.x�Ю	�--W�r��хt@�����ob�t�Ȇ/�	|�DZz^�:mo�pD�鈎�t�-��x�@>�?��0&s. @��Bg��v�Ȗ[����C�&�����7�b��u+9����R��CDѠb�G��������`i����b�~S5����Gu�wQ�L��?�46I6�m*	��+}~������ٓy2@��J��,LH �%ٴ�\��5�,���rɛU��+dt����^��go�db�̮i͒mngI�U��`�"������:�3����:���ǯt�w	ff$��r�}˿BC�P$.�z-��]�Զ`��Y�88S��	��@�:�5� %�#5qɺg�f�4��4R��C�9IcM�$��K(^UѦ�k�s��K`�6�R�Iq[\�b�:}���K��c�[�?!;����~F|�i�'�61ę����L�Ml^���?O�����#
����m�Ps2W$�F(�!��ZTL��+����YN�K�ۓ�بb����-t����q�y�o�8�c*�]�B���r%�i��/��a��g>��XC]<���d
�R�͂�����tq�
�0�&�N� ?�	~��Ўͺ�910�5OM��6��pl�d�a���o��w��L��LOF+�q�Gm)�~ݨ_�,�2y��G�z������y�����Ih��ʤ@M�8�裺uƞhy#�M7�cۧc��{¿�5��E~Ag��ǣ��ػ����X��ɠ���u�a�^�5軾�tB��"���el�,)J�,�p[�Jn5�m�DP�?e�ϊ6d'Q�%�H�cj��=�]V�ё�db�um��C5ϖJ��?q�d�\Kr4K�:�L�z�⩙�U`�C�,u('�� �z�C�)�V��!��^k&�0}mt���nY���o��Mc%�ɼj����ω���4 +)�ߒwM�F��E��O�$�+��
:H�v�X����ȇ�`�������<�PI~�$Mh&ػ{�AҖkP���� �Y��+١�8-���Q�M���x̈MrcR8l�r��<,���܅d� ��=�}[�D�88y�G��D0E+��� �х1�k��U��8}�㠇�1&�RSH�Y�����7�-��+�U�����lc}1��� `��5j,��Y�`�xLP0�����S�}ϭ%|$��ޔ�fBVSG���	4�ó=3    ������x�-��e	t��jPG6�A�L�����͞,�$�ҵa��UaF� ���
�8�F�X�2$��2�ɔ��J�`�<iE#I��g�9 �P��P�x��5�g��gҞ�����C�筤	@(�'�@&ܱ]�2��R�k[%��"�I��K�Q��� +�nC�t�^4_��:��r���}F�����\+9�4|����&�7\{h��I�J	�,���жb!�EDZż�Y�Q��ת;[�;���
Wr����=���C�Zqq_ޡ#ES�3f9Q!�����w�F%[��=׊�=3��}
��v�oQ�V�q��}+N2�8�g����m~Ɨ� �7&M�9�ܾ�:��<�n�ڳ7��4�������޿���핵wW���!�Y@%�l�	=z��\Fi˳m��q����kN�:�K!_�5{V���"�vNv��-�6 ���hZ)E�׫�q����i:lR�%��P.a�p��Y��u���D�F�H��[S�����9��5Y��ã��q��U��8>�o4N��%|�X�~��%pH*�f�l7���R�A��e!?��٩l��8����5#--�����3s�[U��]�f������?���Ut�tNε�a��5w�����`7%����m�6�ڌ}qب����E��3r
�s���U��x=z �\y�1�ݑ��#� L�����9�ZN�.�y�]��HE��E�/���z*F��Jt����42���P��J���6��=RTm�N�dKYV	To��Яt�
����/�;����FCFa�?���kv�ަ���}����萬:cw�1����< ��<��i���<T���w�{=��9¿k����^��aca0�c��h6F�q\?;�֬���а�d|)���C�0K1��CQoj -�D#����z����6�d�YKY8!}�箯 (�o�=s G.lF�*���@��I��7H~6Ir��E�=��$J�|��B����
ev5g���L���va�U��ã�l���yq�u31�\�����4�o	~�R��+�d�doB�NdX���N�V�VQ��-fPh��~4�����ָ�߭|jf2gSp���ٮ�끸�-��W�E�&�j�av0��T����8<�M�����6O�nyX���a��F?�= 8��M�G����Z��Y�@GW&zT1Eo�Al	Zy �"��
uTN��"b���h#�����n��DΒJ��7���N�e@=�-
2��'%�Ǐ��<��~K�B��N���ѵ���Ӈ&�Cr.˱;�+��C�S����N(�3�����f�^\~�L3����6 �[�Z����Z�9e�D�qzr�%@�1E����5Z��_v-\E_�M�+�彍�fc����;���E��}�I�!yW��Wu��R+~��L����A,p�]���7{����7϶1q3cGo`�ƶ9���n�\/�&��c�]Ǽ���::C������:g��劦צ+����o�����D��a�;2K��U S.�k�#�S�e}�m�M��,~�k��+zӐ�@tS���(�e�P�LTI.X����y�".E��E:&�:E�ץ�A70�jZ�
䨴��1�Kϊ��b���j��7�g��^Ć3�X�3�q�̧{-_&�K�GW$ւV��C���!&���n�cS��C��?צ�[�v?�i�A�<�O\�~�2��#�
�T���@;�D{fm$Q
'nٰ]�i����{W?T6���V�o�0Q15��鴥nQozS=���3��b�]`G�j:NvJ򾕤6ʖ�x?���o{$qt����=�߶#�&Sз{J��Q���O?�;��N7޷n��M/Y�)������.���Y��ԁ��L2��Mt�h�['�G�;�y�J���P�'צT|�l@6��V����N+޷V|{��
CѪ���6��`��[jM��Z@��Ċ��QY�yj�Ǎ��o-�d��#�q��U�ڇ&�jz٪������9W$\c���R�<k�y�;g��1�BW�%=G�"Y��bB�n��r�j� �E�J���W&�6�h��JEj�Ҵrrq|X�z���#����x4�q��������	��F����s�{5�Ώw��������m�O�j0����C��N����*^�9��Eb"&�F����'�E<�L.�����T�P3[Ğpg��"��
����Ul$�%)7�4�4����Bo�,AGgQD��G�?+Q��a(i���H�a[�*����3yu5�l���kꒁA���e����
�~�W�����L>V%c̱M&5�:"BNK�Ő�T�XSH�ڊ�?�iu��U,�d�	�H�$s�Y���ɫ_���d����YBZ� kKVd�X`#ni63.�+o�Vaa(�H@�YKZ|� ]	�Ӧ3U]� ����3���י�*�y�e_>�R�V��k��O�@�Y�+����;�4��Th^tU~�1iۨ�T�؁�y�颪�g�L7˿�Wm���*�2��R0H<-t�uQ��%-ݎ�r���Ă����<��Jk�r��!�f��U�@�Dn��s���7Ѿ��%�e�bd���C��ny��'M��1&����S��!�;<�e"&kzv���O�L�jM{����xT��Y�Ȉ�6��_���'��lկє����yU�U���w&�k
)P�
s� 1�Ԣ;vj�[.��+�n�0%���������u_#3�Y�IVn�4��}��]����"��;����N9(
��K�C���e*���d��U*9 �z�c��&\O��K� ~@�]P��e�,o�g��Z�D�A��K�$ M+����F<�A�홗��֬ ����X�$ʾ{/�͑�#����h���;�r0->�ـ.����r{���x�:�P�����|��o�y����oל^ϣ Q�k�y4�5��I1�m�2oc `�[l&�	����W0��fB��% �2!jsrӝ���g-!�86��ݢQľ��,��
�S����[���+G�����z;���EO��i����'����0z�R���F,��*�U�<��Y!O��G )$@ ��oKB�ys'3�����dӦ\���H�|D��3$Ԧ
�}?{��؛�}д�ӾE>��QJ��$�3�|�R?E������5�5?&�L�c���u��l��#��\2�Neў�9��d#�]�_<�FLlʓ�"T�QLl{
�c��J��#���J��|��k�XJ��h�-C���W �A�(��	$�ш	�fh!�U���VSG��Pp:���z\�g�b-4.��&rz�
�������L�Rk����w�e�������ZG�\��� B���BG�Grܦ�N�`�7��q��LҠYG$��+I�T D(T�,3��R_�R��,5S����+�� �b"nQ�n7{�i2���7��̀n<[p_������w�;��@�l��0��k�3�[Έ�t;N�x��v����^��S(�w�n���Jl�%�I��ۜr�YW�6{
p:2�.;��|c_�Lm�t!i��q�-k_�%V4�3&v* s�iRK���|������f䳮�G&��G`Zp�p��B䉷-���F�=
�ᾐ�B�"�Pl��g0�(���;���^]\�x�b^��h2"]��O�ߦ|L�}�`�"�+��>9A�:L�,W2c5ɀ4�����,� �d覸*���)F�3@���P�w"ʘ� �I_
l:d���I���0�fSC/I�>���x(�Ex�-�׮���+3>��j�ں�vOߦh���&��鰺lɻ��E3� ��	ڐqf<Y�f(9Ч�5�g�\ pbZ�:��H9�%����i_��ⓟ��MyV�e����b�Hz���P�m[��jV�hǦ�'j"� bz�
�@����۞q�3[Ꟑ��?r� x����G��2���B�T�,z�3�G���L\���i�(�Z���9+n4]OC��VC�J<�XR��n�eCy�K���7�Zy�6 �  �ߑOpy���-c��+�Ι�f%���J��AX�N.��Y��M�����LW/AP@n��9~}�y�u&��8�{,�U���Əࡷ�0Lz�i # ���f�ҕ�::�Ҵ��}�x��*�Y?�-TM�#����,��o��6}��A�/)�9I6
�(��u`���Ou��$����Q������~�=is��莜��j;#�j�|rۭ�?���"��*s�#r�)R�SL8���� z^��ޓp���I�%C3撠ogݛ2�te?�m�}���}X叏�9��:����i�M��7�I"R�J���4RH� T��������������8+���NI�gh��,ϻ钄���G��C��>�۠(��\&p"���-��\��މĽ(�-7-g+�%�̼Dk���L���4��ӐсĻ.���;�S���@�l�z>��d�&�&�ѫ
�OT��T$��[�釓Ԁ��£9�\����ł�����˸کxv�N恢�}����'���1�g���0���(�"qB�"�d(:\8E��U 3d9�`����"�"��0��~���j�$S���Y�ʬ�P�sI
K���8;}'BB:qF��s�y��Z͔(S�q�N_��jMI�]pza�xv��$B#��kV9AE	jL�_QZS��K����� ;v=�=��.�n��8:8�?:����Dq𐁗]F]���e;IӬg�N:���vV/��߉h�VdK'��c�1�^���kH��Z������Au�.d�捔s�8f�`��^R9��k����4��?Cd3�fA_B�4�I,.X)e$�6m�ܮm��u�
�<��߅@��;V.��BU�
��0��yi���/q��I!�贀I�d��zN�Z&
��w!��o�X���oi�Un¦E�D���=r�O�W���WG���,�H!E��A/�g��u &��\�gO��5��a���)v�ME���~0�1���d�.y�:�50-� �pb�Y����Ę������$WK3e:�J�|�㹸ZeK����Cři��@�	�j�`�8����� ��Z6�B�����.��m
Åh�J�s����Z�f��J�@�2j"��3�Jmaö>�_���IZ�7��A� c�-�E�^��Lf\I嫅A�U��D2��'FP��!��$��i�l;j��YPpW�Tim�6^ %5�9��u�4��]箇����u��NM�$r�^�s��a�[n_x�G�~x��z���ub�  �IB,����~��W!���tKOT�x�Gz�.Gڢ(��i��\��QҖభW��8~�c]]� ����,��~��XV-p��8� �d��q�
 ��QH�!���S)������I�	>{4����&�le܇	w�����yK����O�Dj6\c�6������Q�׌9�8�m^�I�H�q~4!����!��7�z#i��yk�չ������%P޳�Cm%C��9�(Q�p(?�x+ 0~�,��#��yS�|y�<��)�@M�J��r`���ĨHP��w��41p���n��I�4�r�rH|q�&ų��mԐ:Q�����w5�m�@��<�)�Q'1rr\�l�����^h��K�!J�S_����U�M�Iv��$+i�沋��?qL�p��p8�7�d,k������V���(��1��"Z��L�o	K.+�{��:�������.ޣLc�����Y����/J\剽��T�4�m�Ӹ���(��2���i���0Qm�!���]=�XE�I�bz��Z���	n��A��f��@�s|n���"M�
����Np&F�,��8��3�l�����,�t ��g��􃢎�9���j~|����J���=sK���kp(zQX�����2Kԃ5���͡(tbs���*�ݍֹɰH�E2V���CEE�nܘfWw����V�u��  � ��6[��!Ѽ����ế#�������%ȓ��=T��W���7��A��N�,�}.�>!���˲��������}�F&K&�p�~.�'�g$!����Q�Ѐ�Ӟ�H����(��Й�7zń�<�Pƫ�0��˗:
#�n^L�*}�y*N��i������d�Ú�e,�Q�Z�"!��+�gM��Ȁl۴C�+Z���Q��Uۨ� �ܖ����6�8�qD6��a"���r7;O�B6�
aCʱ�dA�[rs�M�)�?wN��v�y��=? /��)�G� -9�OH��Ř��fF�2��g�@9���ҝ/ݰi���mQ���RZFxh�;h�S��~���&~�sA��3�"��2�+I/� UR�jS�v�gֽvw�u�^7m�w�u[T|;�u��-���k�Zy`���(\�G�������T���h�d�sԺtof�ܮt�N��5:�a$��;~���(4Q���\��P\Gq.�d�$'q��ϛ���Ҿ�uKF��"HCi��2��]�3^���k�M/��PX~��Պ��[A�,c�(W�������Q��ς�bɒ�U$��"MF:�A�3\Y���~Z�^��U�Z�SB����)��ī�\�KA��J���݈Q�,����X�?ξj�0����2�i�c�y2��{��U���ё����𔲕��
h_`})�ʯ�)�fX�L^�
=����G1p)jά��%������ uh�J�s�X"�f��6M�)@����̀/ɨ��i�T\X�[qwg�_�if����T�
��m��o�MύJ���6��Xо1�ֱ8\��?5�ͪ��v���i���K+�a	%Ӥl$��X��vb�U_��P�l���R�tvvx�z���-C�=���7����>Ӵ�����C<^Q����q�/މ�3k�ov��5���E���,�1 �c�}�x�sNw|��#ú�tu�|rB��H/L�~�?"S5f#+
0�a^w#����	+=��:�N���s&�	�T����ͫ����?����*��      �      x������ � �      �      x������ � �     