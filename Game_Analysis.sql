use game_analysis;

-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.

alter table player_details modify L1_Status varchar(30);
alter table player_details modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;

alter table level_details2 drop myunknowncolumn;
alter table level_details2 change timestamp start_datetime datetime;
alter table level_details2 modify Dev_Id varchar(10);
alter table level_details2 modify Difficulty varchar(15);
alter table level_details2 add primary key(P_ID,Dev_id,start_datetime);

-- pd (P_ID,PName,L1_status,L2_Status,L1_code,L2_Code)
-- ld (P_ID,Dev_ID,start_time,stages_crossed,level,difficulty,kill_count,
-- headshots_count,score,lives_earned)


-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0

SELECT
	player.P_ID,
	level_.Dev_ID,
    player.PName,
    level_.Difficulty
FROM
	player_details AS player
LEFT JOIN
	level_details2 AS level_
	ON 
	player.P_ID = level_.P_ID
WHERE
	level_.Level = 0
;

-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed

SELECT 
	player.L1_Code,
	AVG(level_.Kill_Count) as Average_Kill_Count
FROM
	player_details AS player
LEFT JOIN
	level_details2 AS level_
	ON 
	player.P_ID = level_.P_ID
WHERE
	level_.Lives_Earned =2 AND level_.Stages_crossed >=3
GROUP BY
	player.L1_Code
;

-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.

SELECT
	level_.Difficulty,
	SUM(level_.Stages_crossed) as Sum_stages_crossed
FROM
	player_details AS player
LEFT JOIN
	level_details2 AS level_
	ON 
	player.P_ID = level_.P_ID
WHERE
	level_.Level =2 AND level_.Dev_ID like ("zm%")
GROUP BY
	level_.Difficulty
ORDER BY 
	Sum_stages_crossed DESC
;

-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.

SELECT *
FROM 
	(SELECT
		player.P_ID,
		COUNT(DATE(level_.start_datetime)) as Unique_dates
	FROM
		player_details AS player
	LEFT JOIN
		level_details2 AS level_
		ON 
		player.P_ID = level_.P_ID
	GROUP BY
		player.P_ID
	) AS unique_
WHERE
	unique_.Unique_dates > 1
;

-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.

SELECT
	player.P_ID,
    level_.Level,
    SUM(level_.Kill_Count) as kill_count
FROM
	player_details AS player
LEFT JOIN
	level_details2 AS level_
	ON 
	player.P_ID = level_.P_ID
WHERE
	kill_count > (SELECT 
						AVG(Kill_Count) as avg_kill_count_medium_diff
					FROM
						level_details2
					WHERE 
						level_details2.Difficulty = "Medium")
GROUP BY 
	player.P_ID, level_.Level, kill_count
;
-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level.

SELECT
	level_.Level,
    sum(level_.Lives_Earned) Lives_Earned
FROM
	level_details2 AS level_
WHERE
	level_.Level != 0
GROUP BY
	level_.Level
ORDER BY 
	level_.Level ASC
;

-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 

SELECT *
FROM(
	SELECT
		level_.Dev_ID,
		level_.Difficulty,
		level_.Score as Score,
		ROW_NUMBER() OVER(PARTITION BY level_.Dev_ID ORDER BY level_.Score DESC) AS RANK_
	FROM
		level_details2 AS level_) AS Score
WHERE
	Score.RANK_ <= 3
;

-- Q8) Find first_login datetime for each device id

SELECT
	level_.Dev_ID,
    MIN(level_.start_datetime) AS First_login
FROM
	level_details2 AS level_
GROUP BY
	level_.Dev_ID
;

-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.

SELECT * 
FROM 
	(SELECT
		level_.Dev_ID,
		level_.Difficulty,
		level_.Score,
		RANK() OVER (PARTITION BY level_.Difficulty ORDER BY level_.Score DESC) AS RANK_
	FROM
		level_details2 AS level_
	ORDER BY 
		level_.Difficulty, Score DESC) AS RANK_
WHERE 
	RANK_ <=5
;

-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.

SELECT 
	first_log.P_ID,
	first_log.Dev_ID,
	first_log.Start_datetime as First_login_date
FROM (SELECT
			level_.P_ID,
			level_.Dev_ID,
			level_.Start_datetime,
			DENSE_RANK() OVER (PARTITION BY P_ID ORDER BY Start_datetime ASC) as RANK_
		FROM
			level_details2 AS level_
		GROUP BY
			level_.P_ID,level_.Dev_ID,
			level_.Start_datetime) AS first_log
WHERE
	RANK_ = 1
;

-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played -- by the player until that date.
-- a) window function

SELECT
    player.PName,
    DATE(level_.start_datetime) AS DATE,
    sum(level_.Kill_Count) AS KILL_COUNT
FROM
	player_details AS player
LEFT JOIN
	level_details2 AS level_
ON 
	player.P_ID = level_.P_ID
GROUP BY
	player.PName, DATE
;
-- b) without window function
SELECT
    player.PName,
    DATE(level_.start_datetime) AS DATE,
    level_.Kill_Count AS KILL_COUNT
FROM
	player_details AS player
LEFT JOIN
	level_details2 AS level_
	ON 
	player.P_ID = level_.P_ID
GROUP BY
	player.PName, DATE, KILL_COUNT
;

-- Q12) Find the cumulative sum of stages crossed over a start_datetime 

SELECT
    level_.start_datetime AS START_DATETIME,
	SUM(level_.Stages_crossed) AS Sum_stages_crossed
FROM
	level_details2 AS level_
GROUP BY
	START_DATETIME
;

-- Q13) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime

SELECT
    DATE(level_.start_datetime) AS start_datetime,
    level_.P_ID,
	SUM(level_.Stages_crossed) AS Sum_stages_crossed
FROM
	level_details2 AS level_
WHERE
	level_.start_datetime != (SELECT
									MAX(level_.start_datetime)
								FROM
									level_details2 AS level_)
GROUP BY
	level_.P_ID, start_datetime
;

-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id
SELECT
	level_.Dev_ID,
    level_.P_ID,
    sum(level_.Score) as sum_of_score
FROM 
	level_details2 AS level_
GROUP BY
	level_.Dev_ID, level_.P_ID
ORDER BY
	sum_of_score DESC
LIMIT
	3
;
-- Q15) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id

SELECT * 
FROM (SELECT
				player.PName,
				sum(level_.Score) AS SUM_SCORE
			FROM
				player_details AS player
			LEFT JOIN
				level_details2 AS level_
				ON 
				player.P_ID = level_.P_ID
			GROUP BY
				player.PName
			ORDER BY
				SUM_SCORE DESC) AS Score
WHERE
	SUM_SCORE > (SELECT
							AVG(level_.Score)/2 as '50%_Average'
						FROM
							level_details2 AS level_)
;



-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.

DELIMITER //

CREATE PROCEDURE TopNHeadshotss(top_n INT)
BEGIN
	WITH RankedHeadshots AS(
		SELECT 
			level_.dev_id AS DEV_ID, 
			level_.Headshots_Count AS Headshots, 
            level_.Difficulty AS Difficulty,
            ROW_NUMBER() OVER(PARTITION BY level_.dev_id ORDER BY level_.Headshots_Count desc) AS RANK_
		FROM
			level_details2 AS level_
		)
        SELECT 
			RankedHeadshots.DEV_ID,
            RankedHeadshots.Headshots,
            RankedHeadshots.Difficulty,
            RankedHeadshots.RANK_
		FROM
			RankedHeadshots
		WHERE
			RankedHeadshots.RANK_ <= top_n;
END //

DELIMITER;

-- Using Function
CALL TopNHeadshotss(5);



-- Q17) Create a function to return sum of Score for a given player_id.

DELIMITER //

CREATE FUNCTION SumOfScores(player_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
	DECLARE total_score INT;
    
    SELECT 
		SUM(score) as Sum_Score
	INTO total_score
    FROM level_details2 as level_
    WHERE player_id = level_.P_ID;
    
    RETURN total_score;
END //

DELIMITER ;

-- Using function
SELECT SumOfScores(211);