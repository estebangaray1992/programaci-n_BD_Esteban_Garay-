--paso 1 creación de usuario
--paso 2 ejecución del Script y el poblado de tablas 

--truncate para eliminar todos los registros de la tabla
--antes de ser usada
TRUNCATE TABLE usuario_clave;

--uso de variable BIND para la fecha del proceso 
--fuera del bloque PL/SQL
VAR b_fecha VARCHAR2(8);
EXEC :b_fecha := TO_CHAR(SYSDATE,'DDMMYYYY');

DECLARE
    --conversión de la fecha 
    v_fecha_proceso  DATE := TO_DATE(:b_fecha,'DDMMYYYY');
     --variables de control 
    v_total_emp      NUMBER := 0;
    v_contador       NUMBER := 0;

    --uso de variables type 
    v_id_emp         empleado.id_emp%TYPE;
    v_run            empleado.numrun_emp%TYPE;
    v_dv             empleado.dvrun_emp%TYPE;
    v_pnombre        empleado.pnombre_emp%TYPE;
    v_snombre        empleado.snombre_emp%TYPE;
    v_ap_paterno     empleado.appaterno_emp%TYPE;
    v_ap_materno     empleado.apmaterno_emp%TYPE;
    v_estado_civil   estado_civil.nombre_estado_civil%TYPE;
    v_sueldo         empleado.sueldo_base%TYPE;
    v_fecha_nac      empleado.fecha_nac%TYPE;
    v_fecha_contrato empleado.fecha_contrato%TYPE;

    /* ======================================================
       VARIABLES DE CÁLCULO
       ====================================================== */
    v_usuario        VARCHAR2(50);
    v_clave          VARCHAR2(50);
    v_anios          NUMBER;
    v_letras_ap      VARCHAR2(2);
    v_nombre_completo VARCHAR2(120);

BEGIN
    --obtención del total de empleados
    SELECT COUNT(*)
    --INTO v_total_emp
    FROM empleado
    WHERE id_emp BETWEEN 100 AND 320;

   --iteración de todos los empleados 
    FOR emp IN (
        SELECT e.*,
               ec.nombre_estado_civil AS estado_civil
        FROM empleado e
        INNER JOIN estado_civil ec
          ON ec.id_estado_civil = e.id_estado_civil
        WHERE e.id_emp BETWEEN 100 AND 320
        ORDER BY e.id_emp
    ) LOOP

        v_contador := v_contador + 1;

        /* Asignación de valores */
        v_id_emp       := emp.id_emp;
        v_run          := emp.numrun_emp;
        v_dv           := emp.dvrun_emp;
        v_pnombre      := emp.pnombre_emp;
        v_snombre      := emp.snombre_emp;
        v_ap_paterno   := emp.appaterno_emp;
        v_ap_materno   := emp.apmaterno_emp;
        v_estado_civil := emp.estado_civil;
        v_sueldo       := emp.sueldo_base;
        v_fecha_nac    := emp.fecha_nac;
        v_fecha_contrato := emp.fecha_contrato;

        --calculo de años trabajados
        v_anios := TRUNC(
            MONTHS_BETWEEN(v_fecha_proceso, v_fecha_contrato) / 12
        );

        --obtención de letras de apellidos usando condicional IF, ELSIF Y ELSE 
        IF v_estado_civil IN ('CASADO','ACUERDO CIVIL') THEN
            v_letras_ap := LOWER(SUBSTR(v_ap_paterno,1,2));

        ELSIF v_estado_civil IN ('DIVORCIADO','SOLTERO') THEN
            v_letras_ap := LOWER(
                SUBSTR(v_ap_paterno,1,1) ||
                SUBSTR(v_ap_paterno,LENGTH(v_ap_paterno),1)
            );

        ELSIF v_estado_civil = 'VIUDO' THEN
            v_letras_ap := LOWER(
                SUBSTR(v_ap_paterno,LENGTH(v_ap_paterno)-2,2)
            );

        ELSE
            v_letras_ap := LOWER(
                SUBSTR(v_ap_paterno,LENGTH(v_ap_paterno)-1,2)
            );
        END IF;

        --construccion nombre de usuario
        v_usuario :=
              LOWER(SUBSTR(v_estado_civil,1,1))
           || UPPER(SUBSTR(v_pnombre,1,3))
           || LENGTH(v_pnombre)
           || '*'
           || SUBSTR(v_sueldo,-1,1)
           || v_dv
           || v_anios;

        IF v_anios < 10 THEN
            v_usuario := v_usuario || 'X';
        END IF;

        --construcción clave
        v_clave :=
              SUBSTR(v_run,3,1)
           || (EXTRACT(YEAR FROM v_fecha_nac) + 2)
           || (SUBSTR(v_sueldo,-3) - 1)
           || v_letras_ap
           || v_id_emp
           || TO_CHAR(v_fecha_proceso,'MMYYYY');

        --nombre completo
        v_nombre_completo :=
            v_pnombre || ' ' ||
            NVL(v_snombre || ' ', '') ||
            v_ap_paterno || ' ' ||
            v_ap_materno;

        --inserción de datos en la tabla final 
        INSERT INTO usuario_clave
        VALUES (
            v_id_emp,
            v_run,
            v_dv,
            v_nombre_completo,
            v_usuario,
            v_clave
        );

    END LOOP;

   --si todo sale bien en la ejecuciíon COMMIT en caso contrario ROLLBACK 
    IF v_contador = v_total_emp THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

END;
/

select * from usuario_clave;