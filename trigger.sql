CREATE DEFINER=`otrs`@`localhost` TRIGGER trg_ticket
AFTER INSERT
ON ticket_history FOR EACH ROW
BEGIN
		
    DECLARE id INT;          
    DECLARE name VARCHAR(255);
    DECLARE history_type_id INT;
    DECLARE ticket_id INT;
    DECLARE article_id INT;     
    DECLARE type_id INT;        
    DECLARE queue_id  INT;      
    DECLARE owner_id  INT;      
    DECLARE priority_id  INT;   
    DECLARE state_id   INT;     
    DECLARE create_time DATETIME;
    DECLARE create_by    INT;   
    DECLARE change_time  DATETIME;
    DECLARE change_by    INT;
    DECLARE Diff INT;
    DECLARE DataInicio DATETIME;
    DECLARE DataFim DATETIME;

    SET id              = new.id;
    SET name            = new.name;
    SET history_type_id = new.history_type_id;
    SET ticket_id       = new.ticket_id;
    SET article_id      = new.article_id;
    SET type_id         = new.type_id;
    SET queue_id        = new.queue_id;
    SET owner_id        = new.owner_id;
    SET priority_id     = new.priority_id;
    SET state_id        = new.state_id;
    SET create_time     = new.create_time;
    SET create_by       = new.create_by;
    SET change_time     = new.change_time;
    SET change_by       = new.change_by;
   
         
		IF (new.history_type_id = 1) THEN	

            SET DataInicio = (select now());

       END IF;
           
        IF (new.history_type_id = 27) THEN		

            SET DataInicio = (
	            SELECT th.create_time
                FROM ticket_history th
                WHERE 
                    th.ticket_id = new.ticket_id
                    AND th.id < new.id
                ORDER BY th.id ASC
                LIMIT 1);
        END IF;
       
SET DataFim = (
                SELECT 
                    (
                    Coalesce(
                                (
                                    SELECT th2.create_time
                                    FROM ticket_history th2
                                    WHERE 
                                        th2.history_type_id IN ( '1', '27' )
                                        AND th2.ticket_id = th1.ticket_id
                                        AND th2.id > th1.id
                                    LIMIT  1
                                ),(
                                SELECT DISTINCT
                                    (
                                        SELECT  
                                            (CASE 
                                                WHEN (th4.state_id in (1,4)) THEN now()
                                                ELSE th4.create_time
                                            END) AS Data
                                        FROM ticket_history th4
                                        WHERE th4.ticket_id = th3.ticket_id
                                        ORDER BY th4.id DESC
                                        LIMIT 1
                                    ) A
                                FROM ticket_history th3
                                WHERE th3.ticket_id = th1.ticket_id)
                            )
                    ) B
                FROM ticket_history th1
                WHERE 
                    th1.history_type_id IN ( '1', '27' )
                    AND th1.id = new.id
                ORDER BY ticket_id
                );
SET Diff = (
SELECT
	(TIMESTAMPDIFF(SECOND,DataInicio, DataFim)) -
	(
			SELECT (IFNULL(count(*), 0) * 86400)
			FROM dimensional.dm_tempo
			WHERE 
				(data >= DataInicio AND data <= DataFim)
				AND WEEKDAY(data) IN (5,6)
	) - 
	(
		SELECT (IFNULL(count(*), 0) * 86400)
		FROM dimensional.dm_tempo
		WHERE 
			(data >= DataInicio AND data <= DataFim)
			AND feriado = 'true'
			AND WEEKDAY(data) IN (0,1,2,3,4)
	));

IF (new.history_type_id = 1) THEN

  	UPDATE ticket T SET T.tempo_decorrido = 0 WHERE T.id = new.ticket_id;
    
ELSEIF (new.history_type_id = 27) THEN

	UPDATE ticket T SET T.tempo_decorrido = Diff WHERE T.id = new.ticket_id;

END IF;


END