--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.1
-- Dumped by pg_dump version 9.6.1

-- Started on 2016-12-05 23:49:04

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 19475)
-- Name: irci; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA irci;


ALTER SCHEMA irci OWNER TO postgres;

SET search_path = irci, pg_catalog;

--
-- TOC entry 221 (class 1255 OID 19476)
-- Name: get_konfig_lang_model(uuid); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION get_konfig_lang_model(p_id_konfig uuid) RETURNS TABLE(id_konfig uuid, kd_konfig text, entity text, path text)
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


ALTER FUNCTION irci.get_konfig_lang_model(p_id_konfig uuid) OWNER TO postgres;

--
-- TOC entry 222 (class 1255 OID 19477)
-- Name: get_str_similarity(text, text); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION get_str_similarity(p_string_1 text, p_string_2 text) RETURNS numeric
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


ALTER FUNCTION irci.get_str_similarity(p_string_1 text, p_string_2 text) OWNER TO postgres;

--
-- TOC entry 223 (class 1255 OID 19478)
-- Name: insert_ekstraksi_referensi_raw(uuid, uuid, text, text, text); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insert_ekstraksi_referensi_raw(p_id_identifier uuid, p_id_referensi_raw uuid, p_authors text, p_title text, p_year text) RETURNS character
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


ALTER FUNCTION irci.insert_ekstraksi_referensi_raw(p_id_identifier uuid, p_id_referensi_raw uuid, p_authors text, p_title text, p_year text) OWNER TO postgres;

--
-- TOC entry 224 (class 1255 OID 19479)
-- Name: insert_referensi_raw(uuid[], text[]); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insert_referensi_raw(p_id_identifier uuid[], p_referensi_raw text[]) RETURNS character
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


ALTER FUNCTION irci.insert_referensi_raw(p_id_identifier uuid[], p_referensi_raw text[]) OWNER TO postgres;

--
-- TOC entry 225 (class 1255 OID 19480)
-- Name: insup_indentifier(uuid[], text[], timestamp without time zone[], text[], character[]); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insup_indentifier(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_status character[]) RETURNS character
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


ALTER FUNCTION irci.insup_indentifier(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_status character[]) OWNER TO postgres;

--
-- TOC entry 226 (class 1255 OID 19481)
-- Name: insup_indentify(text, text, text, timestamp without time zone, text, text, text, text, text, text, uuid, character); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insup_indentify(p_base_url text, p_repo_name text DEFAULT NULL::text, p_protocol_ver text DEFAULT NULL::text, p_earliest_datestamp timestamp without time zone DEFAULT NULL::timestamp without time zone, p_granularity text DEFAULT NULL::text, p_admin_email text DEFAULT NULL::text, p_schema_name text DEFAULT NULL::text, p_repo_identifier text DEFAULT NULL::text, p_delimiter_char text DEFAULT NULL::text, p_sample_oai_identifier text DEFAULT NULL::text, p_id_identify uuid DEFAULT NULL::uuid, p_kd_sts_aktif character DEFAULT '1'::character(1)) RETURNS character
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


ALTER FUNCTION irci.insup_indentify(p_base_url text, p_repo_name text, p_protocol_ver text, p_earliest_datestamp timestamp without time zone, p_granularity text, p_admin_email text, p_schema_name text, p_repo_identifier text, p_delimiter_char text, p_sample_oai_identifier text, p_id_identify uuid, p_kd_sts_aktif character) OWNER TO postgres;

--
-- TOC entry 227 (class 1255 OID 19482)
-- Name: insup_konfig(character, text, text, uuid, character); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insup_konfig(p_kd_kelompok_konfig character, p_kd_konfig text, p_konfig text, p_id_konfig uuid DEFAULT NULL::uuid, p_kd_sts_aktif character DEFAULT '1'::character(1)) RETURNS character
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


ALTER FUNCTION irci.insup_konfig(p_kd_kelompok_konfig character, p_kd_konfig text, p_konfig text, p_id_konfig uuid, p_kd_sts_aktif character) OWNER TO postgres;

--
-- TOC entry 229 (class 1255 OID 19483)
-- Name: insup_metadata(uuid, text, text, text, uuid); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insup_metadata(p_id_identify uuid, p_metadata_prefix text DEFAULT NULL::text, p_metadata_namespace text DEFAULT NULL::text, p_metadata_schema text DEFAULT NULL::text, p_id_metadata_format uuid DEFAULT NULL::uuid) RETURNS character
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


ALTER FUNCTION irci.insup_metadata(p_id_identify uuid, p_metadata_prefix text, p_metadata_namespace text, p_metadata_schema text, p_id_metadata_format uuid) OWNER TO postgres;

--
-- TOC entry 230 (class 1255 OID 19484)
-- Name: insup_record(uuid[], text[], timestamp without time zone[], text[], text[], text[], text[], text[], text[], text[], timestamp without time zone[], text[], text[], text[], text[], text[], text[], text[]); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insup_record(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_title text[], p_subject_keywords text[], p_description text[], p_publisher text[], p_author_creator text[], p_contibutor text[], p_date_submission timestamp without time zone[], p_resource_type text[], p_format text[], p_resource_identifier text[], p_source text[], p_bahasa text[], p_relation text[], p_right_management text[]) RETURNS character
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


ALTER FUNCTION irci.insup_record(p_id_identify uuid[], p_oai_identifier text[], p_datestamp timestamp without time zone[], p_set_spec text[], p_title text[], p_subject_keywords text[], p_description text[], p_publisher text[], p_author_creator text[], p_contibutor text[], p_date_submission timestamp without time zone[], p_resource_type text[], p_format text[], p_resource_identifier text[], p_source text[], p_bahasa text[], p_relation text[], p_right_management text[]) OWNER TO postgres;

--
-- TOC entry 231 (class 1255 OID 19485)
-- Name: insup_sets(uuid, text, text, uuid); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insup_sets(p_id_identify uuid DEFAULT NULL::uuid, p_set_name text DEFAULT NULL::text, p_set_spec text DEFAULT NULL::text, p_id_sets uuid DEFAULT NULL::uuid) RETURNS character
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


ALTER FUNCTION irci.insup_sets(p_id_identify uuid, p_set_name text, p_set_spec text, p_id_sets uuid) OWNER TO postgres;

--
-- TOC entry 232 (class 1255 OID 19486)
-- Name: insup_toolkit(uuid, text, text, text, text, text, text); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION insup_toolkit(p_id_identify uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_author_name text DEFAULT NULL::text, p_author_email text DEFAULT NULL::text, p_version text DEFAULT NULL::text, p_url text DEFAULT NULL::text, p_compression text DEFAULT NULL::text) RETURNS character
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


ALTER FUNCTION irci.insup_toolkit(p_id_identify uuid, p_title text, p_author_name text, p_author_email text, p_version text, p_url text, p_compression text) OWNER TO postgres;

--
-- TOC entry 233 (class 1255 OID 19487)
-- Name: list_identifier(uuid, integer, integer); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION list_identifier(p_id_identify uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid, p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_identifier uuid, oai_identifier text, datestamp timestamp without time zone, set_spec text, title text, resource_identifier text, jml_referensi integer)
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


ALTER FUNCTION irci.list_identifier(p_id_identify uuid, p_jml_data integer, p_offset integer) OWNER TO postgres;

--
-- TOC entry 228 (class 1255 OID 19488)
-- Name: list_jurnal(integer, integer); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION list_jurnal(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_identify uuid, repo_name text, base_url text, admin_email text, jml_artikel integer, last_updated text)
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


ALTER FUNCTION irci.list_jurnal(p_jml_data integer, p_offset integer) OWNER TO postgres;

--
-- TOC entry 234 (class 1255 OID 19489)
-- Name: list_konfig_lang_model(integer, integer); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION list_konfig_lang_model(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_konfig uuid, kd_konfig text, entity text, path text)
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


ALTER FUNCTION irci.list_konfig_lang_model(p_jml_data integer, p_offset integer) OWNER TO postgres;

--
-- TOC entry 235 (class 1255 OID 19490)
-- Name: list_konfig_user_level(integer, integer); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION list_konfig_user_level(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_konfig uuid, kd_konfig text, userlevel integer)
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


ALTER FUNCTION irci.list_konfig_user_level(p_jml_data integer, p_offset integer) OWNER TO postgres;

--
-- TOC entry 236 (class 1255 OID 19491)
-- Name: list_referensi_raw(integer, integer); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION list_referensi_raw(p_jml_data integer DEFAULT 0, p_offset integer DEFAULT 0) RETURNS TABLE(no_baris integer, id_referensi_raw uuid, id_identifier uuid, referensi_raw text, tgl_created timestamp without time zone, status character, title text)
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


ALTER FUNCTION irci.list_referensi_raw(p_jml_data integer, p_offset integer) OWNER TO postgres;

--
-- TOC entry 237 (class 1255 OID 19492)
-- Name: list_unextracted_referensi_raw(); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION list_unextracted_referensi_raw() RETURNS TABLE(no_baris integer, id_referensi_raw uuid, id_identifier uuid, referensi_raw text, tgl_created timestamp without time zone, status character, title text)
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


ALTER FUNCTION irci.list_unextracted_referensi_raw() OWNER TO postgres;

--
-- TOC entry 238 (class 1255 OID 19493)
-- Name: test_py(); Type: FUNCTION; Schema: irci; Owner: postgres
--

CREATE FUNCTION test_py() RETURNS TABLE(repo_name text, base_url text)
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


ALTER FUNCTION irci.test_py() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 187 (class 1259 OID 19494)
-- Name: authors; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE authors (
    id_authors uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    author_name text,
    affiliation text[],
    kode_author text,
    email text,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE authors OWNER TO postgres;

--
-- TOC entry 188 (class 1259 OID 19503)
-- Name: harvesting_info; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE harvesting_info (
    id_harvesting_info uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_identify uuid,
    tgl_registrasi timestamp without time zone,
    tgl_retrieve_identify timestamp without time zone,
    last_datestamp_identifier timestamp without time zone,
    jml_identifier integer,
    tgl_retrieve_record timestamp without time zone,
    last_datestamp_record timestamp without time zone,
    jml_record integer,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL,
    tgl_retrieve_referensi_raw timestamp without time zone DEFAULT now() NOT NULL,
    jml_referensi_raw integer
);


ALTER TABLE harvesting_info OWNER TO postgres;

--
-- TOC entry 189 (class 1259 OID 19510)
-- Name: identifier; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE identifier (
    id_identifier uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_identify uuid NOT NULL,
    oai_identifier text,
    datestamp timestamp without time zone,
    set_spec text,
    status character(1),
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE identifier OWNER TO postgres;

--
-- TOC entry 190 (class 1259 OID 19519)
-- Name: identify; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE identify (
    id_identify uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    repo_name text,
    base_url text,
    protocol_ver text,
    earliest_datestamp timestamp without time zone,
    granularity text,
    admin_email text,
    schema_name text,
    repo_identifier text,
    delimiter_char text,
    sample_oai_identifier text,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL,
    kd_sts_aktif character(1) DEFAULT 1 NOT NULL
);


ALTER TABLE identify OWNER TO postgres;

--
-- TOC entry 191 (class 1259 OID 19529)
-- Name: kelompok_konfig; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE kelompok_konfig (
    kd_kelompok_konfig character(1) NOT NULL,
    kelompok_konfig text,
    kd_sts_aktif character(1) DEFAULT 1 NOT NULL,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE kelompok_konfig OWNER TO postgres;

--
-- TOC entry 192 (class 1259 OID 19538)
-- Name: konfig; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE konfig (
    id_konfig uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    kd_kelompok_konfig character(1),
    kd_konfig text,
    konfig text,
    kd_sts_aktif character(1) DEFAULT 1 NOT NULL,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE konfig OWNER TO postgres;

--
-- TOC entry 193 (class 1259 OID 19548)
-- Name: metadata_formats; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE metadata_formats (
    id_metadata_format uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_identify uuid NOT NULL,
    metadata_prefix text,
    metadata_namespace text,
    metadata_schema text,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE metadata_formats OWNER TO postgres;

--
-- TOC entry 194 (class 1259 OID 19557)
-- Name: metadata_referensi_raw; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE metadata_referensi_raw (
    id_ekstraksi_referensi_raw uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_referensi_raw uuid,
    id_identifier uuid,
    authors text,
    title text,
    theyear text,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL,
    status character(1) DEFAULT 0 NOT NULL
);


ALTER TABLE metadata_referensi_raw OWNER TO postgres;

--
-- TOC entry 195 (class 1259 OID 19567)
-- Name: records; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE records (
    id_record uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_identify uuid NOT NULL,
    oai_identifier text,
    datestamp timestamp without time zone,
    set_spec text,
    title text,
    subject_keywords text,
    description text,
    publisher text,
    author_creator text[],
    contributor text[],
    date_submission date,
    resource_type text[],
    format text,
    resource_identifier text,
    source text[],
    bahasa text,
    relation text,
    right_management text[],
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL,
    tgl_tokenized timestamp without time zone
);


ALTER TABLE records OWNER TO postgres;

--
-- TOC entry 196 (class 1259 OID 19576)
-- Name: referensi_raw; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE referensi_raw (
    id_referensi_raw uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_identifier uuid,
    referensi_raw text,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL,
    status character(1) DEFAULT 0 NOT NULL
);


ALTER TABLE referensi_raw OWNER TO postgres;

--
-- TOC entry 197 (class 1259 OID 19586)
-- Name: sets; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE sets (
    id_sets uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_identify uuid NOT NULL,
    set_name text,
    set_spec text,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE sets OWNER TO postgres;

--
-- TOC entry 198 (class 1259 OID 19595)
-- Name: toolkit; Type: TABLE; Schema: irci; Owner: postgres
--

CREATE TABLE toolkit (
    id_toolkit uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_identify uuid,
    title text,
    author_name text,
    author_email text,
    version text,
    url text,
    compression text,
    tgl_created timestamp without time zone DEFAULT now() NOT NULL,
    tgl_updated timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE toolkit OWNER TO postgres;

--
-- TOC entry 2127 (class 2606 OID 21928)
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (id_authors);


--
-- TOC entry 2129 (class 2606 OID 21930)
-- Name: harvesting_info harvesting_info_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY harvesting_info
    ADD CONSTRAINT harvesting_info_pkey PRIMARY KEY (id_harvesting_info);


--
-- TOC entry 2134 (class 2606 OID 21932)
-- Name: identifier identifier_oai_identifier_key; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY identifier
    ADD CONSTRAINT identifier_oai_identifier_key UNIQUE (oai_identifier);


--
-- TOC entry 2136 (class 2606 OID 21934)
-- Name: identifier identifier_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY identifier
    ADD CONSTRAINT identifier_pkey PRIMARY KEY (id_identifier);


--
-- TOC entry 2139 (class 2606 OID 21936)
-- Name: identify identify_base_url_key; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY identify
    ADD CONSTRAINT identify_base_url_key UNIQUE (base_url);


--
-- TOC entry 2142 (class 2606 OID 21938)
-- Name: identify identify_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY identify
    ADD CONSTRAINT identify_pkey PRIMARY KEY (id_identify);


--
-- TOC entry 2144 (class 2606 OID 21940)
-- Name: kelompok_konfig kelompok_konfig_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY kelompok_konfig
    ADD CONSTRAINT kelompok_konfig_pkey PRIMARY KEY (kd_kelompok_konfig);


--
-- TOC entry 2146 (class 2606 OID 21943)
-- Name: konfig konfig_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY konfig
    ADD CONSTRAINT konfig_pkey PRIMARY KEY (id_konfig);


--
-- TOC entry 2150 (class 2606 OID 21945)
-- Name: metadata_formats metadata_formats_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY metadata_formats
    ADD CONSTRAINT metadata_formats_pkey PRIMARY KEY (id_metadata_format);


--
-- TOC entry 2152 (class 2606 OID 21947)
-- Name: metadata_referensi_raw metadata_referensi_raw_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY metadata_referensi_raw
    ADD CONSTRAINT metadata_referensi_raw_pkey PRIMARY KEY (id_ekstraksi_referensi_raw);


--
-- TOC entry 2157 (class 2606 OID 21949)
-- Name: records records_oai_identifier_key; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY records
    ADD CONSTRAINT records_oai_identifier_key UNIQUE (oai_identifier);


--
-- TOC entry 2159 (class 2606 OID 21954)
-- Name: records records_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY records
    ADD CONSTRAINT records_pkey PRIMARY KEY (id_record);


--
-- TOC entry 2161 (class 2606 OID 21956)
-- Name: referensi_raw referensi_raw_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY referensi_raw
    ADD CONSTRAINT referensi_raw_pkey PRIMARY KEY (id_referensi_raw);


--
-- TOC entry 2165 (class 2606 OID 21958)
-- Name: sets sets_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY sets
    ADD CONSTRAINT sets_pkey PRIMARY KEY (id_sets);


--
-- TOC entry 2167 (class 2606 OID 21960)
-- Name: toolkit toolkit_id_identify_key; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY toolkit
    ADD CONSTRAINT toolkit_id_identify_key UNIQUE (id_identify);


--
-- TOC entry 2169 (class 2606 OID 21978)
-- Name: toolkit toolkit_pkey; Type: CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY toolkit
    ADD CONSTRAINT toolkit_pkey PRIMARY KEY (id_toolkit);


--
-- TOC entry 2130 (class 1259 OID 21979)
-- Name: identifier_id_identifier_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX identifier_id_identifier_idx ON identifier USING btree (id_identifier);


--
-- TOC entry 2131 (class 1259 OID 21980)
-- Name: identifier_id_identify_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX identifier_id_identify_idx ON identifier USING btree (id_identify);


--
-- TOC entry 2132 (class 1259 OID 21986)
-- Name: identifier_oai_identifier_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX identifier_oai_identifier_idx ON identifier USING btree (oai_identifier);


--
-- TOC entry 2137 (class 1259 OID 21988)
-- Name: identify_base_url_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX identify_base_url_idx ON identify USING btree (base_url);


--
-- TOC entry 2140 (class 1259 OID 21990)
-- Name: identify_id_identify_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX identify_id_identify_idx ON identify USING btree (id_identify);


--
-- TOC entry 2147 (class 1259 OID 21991)
-- Name: metadata_formats_id_identify_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX metadata_formats_id_identify_idx ON metadata_formats USING btree (id_identify);


--
-- TOC entry 2148 (class 1259 OID 21992)
-- Name: metadata_formats_id_metadata_format_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX metadata_formats_id_metadata_format_idx ON metadata_formats USING btree (id_metadata_format);


--
-- TOC entry 2153 (class 1259 OID 21993)
-- Name: records_id_identify_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX records_id_identify_idx ON records USING btree (id_identify);


--
-- TOC entry 2154 (class 1259 OID 21994)
-- Name: records_id_record_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX records_id_record_idx ON records USING btree (id_record);


--
-- TOC entry 2155 (class 1259 OID 21995)
-- Name: records_oai_identifier_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX records_oai_identifier_idx ON records USING btree (oai_identifier);


--
-- TOC entry 2162 (class 1259 OID 21996)
-- Name: sets_id_identify_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX sets_id_identify_idx ON sets USING btree (id_identify);


--
-- TOC entry 2163 (class 1259 OID 21997)
-- Name: sets_id_sets_idx; Type: INDEX; Schema: irci; Owner: postgres
--

CREATE INDEX sets_id_sets_idx ON sets USING btree (id_sets);


--
-- TOC entry 2170 (class 2606 OID 21998)
-- Name: harvesting_info harvesting_info_id_identify_fkey; Type: FK CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY harvesting_info
    ADD CONSTRAINT harvesting_info_id_identify_fkey FOREIGN KEY (id_identify) REFERENCES identify(id_identify);


--
-- TOC entry 2171 (class 2606 OID 22003)
-- Name: konfig konfig_kd_kelompok_konfig_fkey; Type: FK CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY konfig
    ADD CONSTRAINT konfig_kd_kelompok_konfig_fkey FOREIGN KEY (kd_kelompok_konfig) REFERENCES kelompok_konfig(kd_kelompok_konfig);


--
-- TOC entry 2172 (class 2606 OID 22008)
-- Name: metadata_referensi_raw metadata_referensi_raw_id_identifier_fkey; Type: FK CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY metadata_referensi_raw
    ADD CONSTRAINT metadata_referensi_raw_id_identifier_fkey FOREIGN KEY (id_identifier) REFERENCES identifier(id_identifier);


--
-- TOC entry 2174 (class 2606 OID 22013)
-- Name: referensi_raw referensi_raw_id_identifier_fkey; Type: FK CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY referensi_raw
    ADD CONSTRAINT referensi_raw_id_identifier_fkey FOREIGN KEY (id_identifier) REFERENCES identifier(id_identifier);


--
-- TOC entry 2173 (class 2606 OID 22018)
-- Name: metadata_referensi_raw referensi_raw_id_identifier_fkey; Type: FK CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY metadata_referensi_raw
    ADD CONSTRAINT referensi_raw_id_identifier_fkey FOREIGN KEY (id_referensi_raw) REFERENCES referensi_raw(id_referensi_raw);


--
-- TOC entry 2175 (class 2606 OID 22023)
-- Name: toolkit toolkit_id_identify_fkey; Type: FK CONSTRAINT; Schema: irci; Owner: postgres
--

ALTER TABLE ONLY toolkit
    ADD CONSTRAINT toolkit_id_identify_fkey FOREIGN KEY (id_identify) REFERENCES identify(id_identify);


-- Completed on 2016-12-05 23:49:04

--
-- PostgreSQL database dump complete
--

