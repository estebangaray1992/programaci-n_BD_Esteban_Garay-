--version final Esteban Garay 
--creación de usuario 
--poblado de tabla 
--set serveroutput on (para habilitar salida DBMS)
--creación de script

--uso de variable BIND para fechas y valores 

VAR b_annio NUMBER;
EXEC :b_annio := EXTRACT(YEAR FROM SYSDATE) - 1;

VAR b_tramo1_min NUMBER;
VAR b_tramo1_max NUMBER;
VAR b_tramo2_max NUMBER;

EXEC :b_tramo1_min := 500000;
EXEC :b_tramo1_max := 700000;
EXEC :b_tramo2_max := 900000;

DECLARE
    /* =========================
       VARRAY TIPOS TRANSACCIÓN
       ========================= */
    TYPE t_tipo_trans IS VARRAY(2) OF VARCHAR2(40);
    v_tipos_trans t_tipo_trans := t_tipo_trans(
        'Avance en Efectivo',
        'Super Avance en Efectivo'
    );

    /* =========================
       REGISTRO PL/SQL
       ========================= */
    TYPE r_detalle IS RECORD (
        run_cliente          NUMBER,
        dv_cliente           VARCHAR2(1),
        nro_tarjeta          NUMBER,
        nro_transaccion      NUMBER,
        fecha_transaccion    DATE,
        tipo_transaccion     VARCHAR2(40),
        monto_total          NUMBER
    );

    v_det r_detalle;

    /* =========================
       CURSORES EXPLÍCITOS
       ========================= */
    CURSOR c_detalle IS
        SELECT c.run_cliente,
               c.dv_cliente,
               t.nro_tarjeta,
               tr.nro_transaccion,
               tr.fecha_transaccion,
               tr.tipo_transaccion,
               tr.monto_total
        FROM cliente c
        JOIN tarjeta t   ON t.id_cliente = c.id_cliente
        JOIN transaccion tr ON tr.nro_tarjeta = t.nro_tarjeta
        WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = :b_annio
          AND tr.tipo_transaccion IN (
                'Avance en Efectivo',
                'Super Avance en Efectivo'
          )
        ORDER BY tr.fecha_transaccion, c.run_cliente;

    CURSOR c_resumen (p_mes NUMBER, p_tipo VARCHAR2) IS
        SELECT SUM(monto_total) total_monto
        FROM transaccion
        WHERE EXTRACT(YEAR FROM fecha_transaccion) = :b_annio
          AND EXTRACT(MONTH FROM fecha_transaccion) = p_mes
          AND tipo_transaccion = p_tipo;

    /* =========================
       VARIABLES DE CÁLCULO
       ========================= */
    v_aporte        NUMBER := 0;
    v_total_monto  NUMBER := 0;
    v_mes           NUMBER;
    v_iteraciones   NUMBER := 0;
    v_total_regs    NUMBER := 0;

    /* =========================
       EXCEPCIÓN USUARIO
       ========================= */
    e_monto_invalido EXCEPTION;

BEGIN
    /* =========================
       LIMPIEZA DE TABLAS
       ========================= */
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_APORTE_SBIF';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_APORTE_SBIF';

    /* =========================
       TOTAL DE REGISTROS
       ========================= */
    SELECT COUNT(*)
    INTO v_total_regs
    FROM transaccion
    WHERE EXTRACT(YEAR FROM fecha_transaccion) = :b_annio
      AND tipo_transaccion IN (
            'Avance en Efectivo',
            'Super Avance en Efectivo'
      );

    /* =========================
       PROCESO DETALLE
       ========================= */
    OPEN c_detalle;
    LOOP
        FETCH c_detalle INTO v_det;
        EXIT WHEN c_detalle%NOTFOUND;

        IF v_det.monto_total <= 0 THEN
            RAISE e_monto_invalido;
        END IF;

        /* Cálculo aporte en PL/SQL */
        IF v_det.monto_total BETWEEN :b_tramo1_min AND :b_tramo1_max THEN
            v_aporte := ROUND(v_det.monto_total * 0.04);
        ELSIF v_det.monto_total > :b_tramo1_max
           AND v_det.monto_total <= :b_tramo2_max THEN
            v_aporte := ROUND(v_det.monto_total * 0.05);
        ELSE
            v_aporte := ROUND(v_det.monto_total * 0.06);
        END IF;

        INSERT INTO DETALLE_APORTE_SBIF
        VALUES (
            v_det.run_cliente,
            v_det.dv_cliente,
            v_det.nro_tarjeta,
            v_det.nro_transaccion,
            v_det.fecha_transaccion,
            v_det.tipo_transaccion,
            v_det.monto_total,
            v_aporte
        );

        v_iteraciones := v_iteraciones + 1;
    END LOOP;
    CLOSE c_detalle;

    /* =========================
       PROCESO RESUMEN
       ========================= */
    FOR i IN 1 .. v_tipos_trans.COUNT LOOP
        FOR m IN 1 .. 12 LOOP
            OPEN c_resumen(m, v_tipos_trans(i));
            FETCH c_resumen INTO v_total_monto;
            CLOSE c_resumen;

            IF v_total_monto IS NOT NULL THEN
                v_mes := TO_NUMBER(LPAD(m, 2, '0') || :b_annio);

                IF v_total_monto BETWEEN :b_tramo1_min AND :b_tramo1_max THEN
                    v_aporte := ROUND(v_total_monto * 0.04);
                ELSIF v_total_monto > :b_tramo1_max
                   AND v_total_monto <= :b_tramo2_max THEN
                    v_aporte := ROUND(v_total_monto * 0.05);
                ELSE
                    v_aporte := ROUND(v_total_monto * 0.06);
                END IF;

                INSERT INTO RESUMEN_APORTE_SBIF
                VALUES (
                    v_mes,
                    v_tipos_trans(i),
                    v_total_monto,
                    v_aporte
                );
            END IF;
        END LOOP;
    END LOOP;

    /* =========================
       COMMIT CONDICIONAL
       ========================= */
    IF v_iteraciones = v_total_regs THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

--excepciones
EXCEPTION
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('Error: división por cero. El proceso continúa.');

    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Advertencia: registro duplicado. Se omite.');

    WHEN INVALID_CURSOR THEN
        DBMS_OUTPUT.PUT_LINE('Advertencia: cursor inválido. Se controla el error.');

    WHEN e_monto_invalido THEN
        DBMS_OUTPUT.PUT_LINE('Monto inválido detectado. Registro descartado.');

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/


--comprobación de los datos ingresados a las tablas 

SELECT * FROM detalle_aporte_sbif;
SELECT * FROM resumen_aporte_sbif;

