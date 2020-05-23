-- SEQUENCE: public.footprint_fp_id_seq

-- DROP SEQUENCE public.footprint_fp_id_seq;

CREATE SEQUENCE public.footprint_fp_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE public.footprint_fp_id_seq
    OWNER TO postgres;

-- SEQUENCE: public.footprint_temp_fp_id_seq

-- DROP SEQUENCE public.footprint_temp_fp_id_seq;

CREATE SEQUENCE public.footprint_temp_fp_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE public.footprint_temp_fp_id_seq
    OWNER TO postgres;


-- Table: public.footprint

-- DROP TABLE public.footprint;

CREATE TABLE public.footprint
(
    fp_id bigint NOT NULL DEFAULT nextval('footprint_fp_id_seq'::regclass),
    release character varying COLLATE pg_catalog."default" NOT NULL,
    object_type character varying COLLATE pg_catalog."default" NOT NULL,
    object character varying COLLATE pg_catalog."default" NOT NULL,
    date character varying COLLATE pg_catalog."default" NOT NULL,
    hash text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT footprint_pkey PRIMARY KEY (fp_id)
)

TABLESPACE pg_default;

ALTER TABLE public.footprint
    OWNER to postgres;


    -- Table: public.footprint

    -- DROP TABLE public.footprint_temp;

    CREATE TABLE public.footprint_temp
    (
        fp_id bigint NOT NULL DEFAULT nextval('footprint_temp_fp_id_seq'::regclass),
        release character varying COLLATE pg_catalog."default" NOT NULL,
        object_type character varying COLLATE pg_catalog."default" NOT NULL,
        object character varying COLLATE pg_catalog."default" NOT NULL,
        date character varying COLLATE pg_catalog."default" NOT NULL,
        hash text COLLATE pg_catalog."default" NOT NULL,
        hash_footprint text COLLATE pg_catalog."default" NOT NULL,
        CONSTRAINT footprint_temp_pkey PRIMARY KEY (fp_id)
    )

TABLESPACE pg_default;

ALTER TABLE public.footprint_temp
    OWNER to postgres;



-- PROCEDURE: public.sp_comparar(character varying, character varying, character varying)

-- DROP PROCEDURE public.sp_comparar(character varying, character varying, character varying);

CREATE OR REPLACE PROCEDURE public.sp_comparar(
	p_release1 character varying,
	p_release2 character varying,
	INOUT p_result character varying)
LANGUAGE 'plpgsql'

AS $BODY$DECLARE
	objectName text;
	objectTypeName text;
	cadenaSHA256 text;
	resultTableHash1 RECORD;
  resultTableHash2 RECORD;
	objectHash text;
  vParam1 ALIAS FOR $1;
  vParam2 ALIAS FOR $2;
	BEGIN

	delete from footprint_temp;
    FOR resultTableHash1 IN
			 SELECT hash,object,object_type FROM footprint WHERE release = vParam1
	LOOP
		objectTypeName := resultTableHash1.object_type;
		objectName := resultTableHash1.object;
		objectHash := resultTableHash1.hash;
		FOR resultTableHash2 IN
         SELECT hash,object,object_type FROM footprint WHERE release = vParam2 and object = objectName
		LOOP
         INSERT INTO footprint_temp VALUES(DEFAULT,'comparar',objectTypeName,objectName,to_char(current_timestamp, 'DD/MM/YYYY-HH12:MI:SS'),objectHash,resultTableHash2.hash);
		END LOOP;
    END LOOP;
    p_result = 2;
	return;
	END
$BODY$;


-- PROCEDURE: public.sp_create_release(character varying, character varying)

-- DROP PROCEDURE public.sp_create_release(character varying, character varying);

CREATE OR REPLACE PROCEDURE public.sp_create_release(
	p_name character varying,
	INOUT p_result character varying)
LANGUAGE 'plpgsql'

AS $BODY$DECLARE
	allObject text;
	objectName text;
	cadenaSHA256 text;
	resultTable RECORD;
	resultTableName RECORD;
	resultSeq RECORD;
	resultSeqName RECORD;
	resultRou RECORD;
	resultRouName RECORD;
	BEGIN
		---Se crea huella de toda la tabla
		FOR resultTableName IN
			SELECT table_name FROM information_schema.COLUMNS WHERE table_schema = 'public' GROUP BY table_name
		LOOP
			allObject := '';
			objectName := resultTableName.table_name;
			FOR resultTable IN
				SELECT table_name,(table_name,ordinal_position,column_default,column_name,is_nullable,data_type,character_maximum_length,numeric_precision,numeric_precision_radix,numeric_scale) as totalInfo FROM information_schema.COLUMNS WHERE table_schema = 'public' AND table_name = objectName
			LOOP
			allObject := allObject || resultTable.totalInfo;
			END LOOP;

			SELECT INTO cadenaSHA256 digest(allObject, 'sha256');
			INSERT INTO footprint VALUES(DEFAULT,p_name,'table',resultTableName.table_name,to_char(current_timestamp, 'DD/MM/YYYY-HH12:MI:SS'),cadenaSHA256);
		END LOOP;

		---Se crea huella de toda la sequence
		FOR resultSeqName IN
			SELECT sequence_name FROM information_schema.sequences
		LOOP
			allObject := '';
			objectName := resultSeqName.sequence_name;
			FOR resultSeq IN
				SELECT (sequence_name,data_type,numeric_precision,numeric_precision_radix,numeric_scale,start_value,minimum_value,maximum_value,increment) AS totalInfo FROM information_schema.sequences WHERE sequence_name = objectName
			LOOP
			allObject := allObject || resultSeq.totalInfo;
			END LOOP;

			SELECT INTO cadenaSHA256 digest(allObject, 'sha256');
			INSERT INTO footprint VALUES(DEFAULT,p_name,'sequence',resultSeqName.sequence_name,to_char(current_timestamp, 'DD/MM/YYYY-HH12:MI:SS'),cadenaSHA256);
		END LOOP;

		--Se crea la huella de sp y functions
		FOR resultRouName IN
		SELECT routine_name FROM information_schema.routines WHERE routines.specific_schema='public' group by routines.routine_name
	    LOOP
			allObject := '';
			objectName := resultRouName.routine_name;
			FOR resultRou IN
				SELECT (proname, proargnames,pg_catalog.oidvectortypes(proargtypes), prosrc) AS totalInfo FROM pg_catalog.pg_namespace n JOIN pg_catalog.pg_proc proc ON pronamespace = n.oid WHERE nspname = 'public' and proname = objectName
			LOOP
			allObject := allObject || resultRou.totalInfo;
			END LOOP;

			SELECT INTO cadenaSHA256 digest(allObject, 'sha256');
			INSERT INTO footprint VALUES(DEFAULT,p_name,'routine',resultRouName.routine_name,to_char(current_timestamp, 'DD/MM/YYYY-HH12:MI:SS'),cadenaSHA256);
		END LOOP;
		p_result = 1;
	return;
	END
$BODY$;
