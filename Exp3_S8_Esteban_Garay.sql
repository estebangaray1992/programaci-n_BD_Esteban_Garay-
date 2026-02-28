--creación de usuario PRY2206_PRUEBA3
--POBLADO CON TABLAS 
--ejecuto set serveroutput on;

set serveroutput on; 

--creación de codigo 

/* creación de codigo + bloque de prueba */

--trigger 
CREATE OR REPLACE TRIGGER trg_actualiza_total_consumos
AFTER INSERT OR UPDATE OR DELETE ON CONSUMO
FOR EACH ROW
BEGIN

   -- INSERT
   IF INSERTING THEN
      UPDATE TOTAL_CONSUMOS
      SET MONTO_CONSUMOS = MONTO_CONSUMOS + :NEW.MONTO
      WHERE ID_HUESPED = :NEW.ID_HUESPED;

   -- UPDATE
   ELSIF UPDATING THEN
      UPDATE TOTAL_CONSUMOS
      SET MONTO_CONSUMOS = MONTO_CONSUMOS - :OLD.MONTO + :NEW.MONTO
      WHERE ID_HUESPED = :NEW.ID_HUESPED;

   -- DELETE
   ELSIF DELETING THEN
      UPDATE TOTAL_CONSUMOS
      SET MONTO_CONSUMOS = MONTO_CONSUMOS - :OLD.MONTO
      WHERE ID_HUESPED = :OLD.ID_HUESPED;

   END IF;

END;
/

--bloque de prueba - para dejar TOTAL_CONSUMOS con los valores correctos. 
BEGIN

   -- INSERT nuevo consumo
   INSERT INTO CONSUMO (ID_CONSUMO, ID_RESERVA, ID_HUESPED, MONTO)
   VALUES (12000, 1587, 340006, 150);

   -- DELETE consumo
   DELETE FROM CONSUMO
   WHERE ID_CONSUMO = 11473;

   -- UPDATE consumo
   UPDATE CONSUMO
   SET MONTO = 95
   WHERE ID_CONSUMO = 10688;

   COMMIT;

END;
/


--caso 2, creación de PACKAGE
CREATE OR REPLACE PACKAGE PKG_COBRANZA AS

   v_monto_tours NUMBER;

   FUNCTION fn_monto_tours(p_id_huesped NUMBER)
   RETURN NUMBER;

END PKG_COBRANZA;
/

--BODY del PACKAGE
CREATE OR REPLACE PACKAGE BODY PKG_COBRANZA AS

   FUNCTION fn_monto_tours(p_id_huesped NUMBER)
   RETURN NUMBER
   IS
      v_total NUMBER;
   BEGIN

      SELECT NVL(SUM(monto),0)
      INTO v_total
      FROM TOUR
      WHERE id_huesped = p_id_huesped;

      v_monto_tours := v_total;

      RETURN v_total;

   END;

END PKG_COBRANZA;
/

--funcion agencia 
CREATE OR REPLACE FUNCTION fn_agencia(p_id_reserva NUMBER)
RETURN VARCHAR2
IS
   v_agencia VARCHAR2(100);
BEGIN

   SELECT agencia
   INTO v_agencia
   FROM reserva
   WHERE id_reserva = p_id_reserva;

   RETURN v_agencia;

EXCEPTION
   WHEN NO_DATA_FOUND THEN

      INSERT INTO REG_ERRORES
      VALUES (
         SQ_ERROR.NEXTVAL,
         'FN_AGENCIA',
         'No existe agencia para reserva ' || p_id_reserva,
         SYSDATE
      );

      RETURN 'NO REGISTRA AGENCIA';

   WHEN OTHERS THEN

      INSERT INTO REG_ERRORES
      VALUES (
         SQ_ERROR.NEXTVAL,
         'FN_AGENCIA',
         SQLERRM,
         SYSDATE
      );

      RETURN 'NO REGISTRA AGENCIA';

END;
/

--funcion total consumos 
CREATE OR REPLACE FUNCTION fn_total_consumos(p_id_huesped NUMBER)
RETURN NUMBER
IS
   v_total NUMBER;
BEGIN

   SELECT NVL(MAX(monto_consumos),0)
   INTO v_total
   FROM total_consumos
   WHERE id_huesped = p_id_huesped;

   RETURN v_total;

END;
/

--procedimiento principal 
CREATE OR REPLACE PROCEDURE pr_proceso_cobranza (
      p_fecha_proceso   DATE,
      p_valor_dolar     NUMBER
)
IS

   CURSOR c_reservas IS
      SELECT r.id_reserva,
             r.id_huesped,
             r.valor_habitacion,
             r.valor_minibar,
             r.cant_personas,
             r.dias_estadia
      FROM reserva r
      WHERE r.fecha_salida = p_fecha_proceso;

   v_agencia           VARCHAR2(100);
   v_consumos          NUMBER;
   v_tours             NUMBER;
   v_alojamiento       NUMBER;
   v_valor_personas    NUMBER;
   v_subtotal          NUMBER;
   v_descuento_agencia NUMBER;
   v_total_final       NUMBER;

BEGIN

   -- Limpiar tablas
   DELETE FROM DETALLE_DIARIO_HUESPEDES;
   DELETE FROM REG_ERRORES;

   FOR reg IN c_reservas LOOP

      v_agencia := fn_agencia(reg.id_reserva);
      v_consumos := fn_total_consumos(reg.id_huesped);
      v_tours := PKG_COBRANZA.fn_monto_tours(reg.id_huesped);

      v_alojamiento :=
         (reg.valor_habitacion + reg.valor_minibar)
         * reg.dias_estadia;

      v_valor_personas :=
         35 * reg.cant_personas;

      v_subtotal :=
         v_alojamiento
         + v_consumos
         + v_tours
         + v_valor_personas;

      IF UPPER(v_agencia) = 'VIAJES ALBERTI' THEN
         v_descuento_agencia := v_subtotal * 0.12;
      ELSE
         v_descuento_agencia := 0;
      END IF;

      v_total_final := v_subtotal - v_descuento_agencia;

      INSERT INTO DETALLE_DIARIO_HUESPEDES
      VALUES (
         reg.id_huesped,
         v_agencia,
         ROUND(v_alojamiento * p_valor_dolar),
         ROUND(v_consumos * p_valor_dolar),
         ROUND(v_subtotal * p_valor_dolar),
         0,
         ROUND(v_descuento_agencia * p_valor_dolar),
         ROUND(v_total_final * p_valor_dolar)
      );

   END LOOP;

   COMMIT;

END;
/

--ejecución 
BEGIN
   pr_proceso_cobranza(
      TO_DATE('18/08/2021','DD/MM/YYYY'),
      915
   );
END;
/

