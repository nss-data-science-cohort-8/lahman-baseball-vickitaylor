
-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?

WITH vandy AS (
  SELECT DISTINCT 
    c.playerid
  FROM collegeplaying AS c
  INNER JOIN schools AS s
    ON c.schoolid = s.schoolid
  WHERE s.schoolname = 'Vanderbilt University'
)
SELECT
  p.namefirst, 
  p.namelast,
  SUM(s.salary) AS total_salary
FROM vandy AS v
LEFT JOIN people AS p
  ON v.playerid = p.playerid
INNER JOIN salaries AS s
  ON v.playerid = s.playerid
GROUP BY 1, 2
ORDER BY 3 DESC
;


-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

SELECT 
  CASE
    WHEN pos = 'OF' THEN 'Outfield'
    WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
    WHEN pos IN ('P', 'C') THEN 'Battery'
  END AS position, 
  SUM(po) AS total_putouts
FROM fielding
WHERE yearid = 2016
GROUP BY 1
ORDER BY 2
;




-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)

WITH decades AS (
  SELECT
    (yearid / 10) * 10 AS decade, 
    SUM(so) AS strikeouts, 
    SUM(hr) AS homeruns, 
    SUM(g) AS games
  FROM batting
  WHERE yearid >= 1920
  GROUP BY 1
)
SELECT
  decade, 
  ROUND((CAST(strikeouts AS NUMERIC) / games), 2) AS avg_strikeouts, 
  ROUND((CAST(homeruns AS NUMERIC) / games), 2) AS avg_homeruns
FROM decades
;


SELECT
    trunc(yearid, -1) || 's' AS decade,
    AVG(g) AS avg_games_played,
    AVG(so) AS avg_strikeouts_pitching,
    ROUND(SUM(so)::numeric /(SUM(g)::numeric), 2) AS avg_so_per_game,
    ROUND(SUM(hr)::numeric /(SUM(g)::numeric), 2) AS avg_hr_per_game
FROM teams
WHERE yearid >= 1920
GROUP BY decade
ORDER BY decade;

WITH years AS (
	SELECT generate_series(1920, 2020, 10) AS decades
	)
SELECT decades, ROUND(SUM(so) * 1.0/SUM(g), 2) AS avg_strikeouts_per_game
FROM teams AS t
INNER JOIN years
ON t.yearid < (decades + 10) AND t.yearid >= decades
GROUP BY decades;

WITH years AS (
	SELECT generate_series(1920, 2020, 10) AS decades
	)
SELECT decades, ROUND(SUM(hr) * 1.0/SUM(g), 2) AS avg_homeruns_per_game
FROM teams AS t
INNER JOIN years
ON t.yearid < (decades + 10) AND t.yearid >= decades
GROUP BY decades;

-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.



SELECT 
  CONCAT(p.namefirst, ' ', p.namelast) AS name,
  SUM(b.sb) AS stolen_bases, 
  SUM(b.sb) + SUM(b.cs) AS sb_attempts, 
  ROUND((CAST(SUM(b.sb) AS NUMERIC) / (SUM(b.sb) + SUM(b.cs)) * 100), 2) AS sb_percentage
FROM batting AS b
LEFT JOIN people AS p
  ON b.playerid = p.playerid
WHERE b.yearid = 2016
GROUP BY 1
HAVING SUM(b.sb) + SUM(b.cs) >= 20
ORDER BY 4 DESC
;

-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

SELECT
  yearid,
  teamid, 
  MAX(w) AS wins
FROM teams
WHERE wswin = 'N'
  AND yearid BETWEEN 1970 AND 2016
GROUP BY 1, 2
ORDER BY 3 DESC

;
SELECT
  yearid,
  teamid,
  w AS wins
FROM teams
WHERE wswin = 'Y'
  AND yearid BETWEEN 1970 AND 2016
ORDER BY 3
;
SELECT
  yearid,
  teamid,
  w AS wins
FROM teams
WHERE wswin = 'Y'
  AND (yearid BETWEEN 1970 AND 2016 AND yearid <> 1981)
ORDER BY 3
;

WITH wins AS (
  SELECT 
    yearid, 
    teamid, 
    w AS wins, 
    wswin,
    RANK() OVER (PARTITION BY yearid ORDER BY w DESC) AS winrank
  FROM teams
  WHERE yearid BETWEEN 1970 AND 2016 
    AND yearid <> 1981
)
SELECT 
  SUM(CASE WHEN wswin = 'Y' THEN 1 ELSE 0 END) AS times_most_wins_won_ws,
  ROUND(
    CAST(SUM(CASE WHEN wswin = 'Y' THEN 1 ELSE 0 END) AS NUMERIC) 
    / COUNT(DISTINCT yearid), 2) * 100 AS percentage
FROM wins
WHERE winrank = 1
;



-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.


WITH manaward AS(
  SELECT DISTINCT
    playerid, 
    COUNT(DISTINCT lgid) AS leagues
  FROM awardsmanagers
  WHERE awardid = 'TSN Manager of the Year'
    AND lgid IN ('AL', 'NL')
  GROUP BY 1
  HAVING COUNT(DISTINCT lgid) = 2
)
SELECT DISTINCT 
  m.playerid,
  CONCAT(p.namefirst, ' ', p.namelast) AS name, 
  m.yearid, 
  m.lgid, 
  t.teamid, 
  n.name
FROM manaward AS a
INNER JOIN awardsmanagers AS m
  ON a.playerid = m.playerid
INNER JOIN managers AS t
  ON a.playerid = t.playerid
  AND m.yearid = t.yearid
LEFT JOIN teams AS n
  ON t.teamid = n.teamid
  AND m.yearid = n.yearid
LEFT JOIN people AS p
  ON a.playerid = p.playerid
;

-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.


WITH stats AS (
  SELECT 
    p.playerid,
    SUM(p.gs) AS games_started,
    SUM(p.so) AS strike_outs, 
    SUM(s.salary) AS salary
  FROM pitching AS p
  INNER JOIN salaries AS s
    ON p.playerid = s.playerid
  WHERE p.yearid = 2016
  GROUP BY 1
)
SELECT 
  CONCAT(p.namefirst, ' ', p.namelast) AS name,  
  s.salary / s.strike_outs AS efficiency
FROM stats AS s
LEFT JOIN people AS p
  ON s.playerid = p.playerid
WHERE s.games_started >= 10
ORDER BY 2 
;

-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.


WITH hits AS ( 
  SELECT 
    b.playerid, 
    CONCAT(p.namefirst, ' ', p.namelast) AS name,    
    SUM(b.h) AS total_hits
  FROM batting AS b
  LEFT JOIN people AS p
    ON b.playerid = p.playerid
  GROUP BY 1, 2
  HAVING SUM(b.h) >= 3000
)
SELECT 
  b.playerid, 
  b.name, 
  b.total_hits,
  h.yearid AS year_inducted
FROM hits AS b
LEFT JOIN halloffame AS h
  ON b.playerid = h.playerid
  AND h.inducted = 'Y'
WHERE total_hits >= 3000
;

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.


WITH hits AS ( 
  SELECT 
    b.playerid,
    b.teamid,
    CONCAT(p.namefirst, ' ', p.namelast) AS name,    
    SUM(b.h) AS total_hits, 
    COUNT(teamid) OVER(PARTITION BY b.playerid) AS team_count
  FROM batting AS b
  LEFT JOIN people AS p
    ON b.playerid = p.playerid
  GROUP BY 1, 2, 3
  HAVING SUM(b.h) > 1000
)
SELECT
  playerid, 
  teamid, 
  name, 
  total_hits
FROM hits
WHERE team_count >= 2
; 


-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

WITH home_runs AS (
  SELECT 
    b.playerid,
    CONCAT(p.namefirst, ' ', p.namelast) AS name,    
    b.yearid,
    SUM(b.hr) AS home_runs, 
    COUNT(yearid) OVER(PARTITION BY b.playerid) AS year_count
  FROM batting AS b
  LEFT JOIN people AS p
    ON b.playerid = p.playerid
  GROUP BY 1, 2, 3
  HAVING SUM(b.hr) > 0
) 
, sixteen AS (
  SELECT 
    playerid,
    name,
    home_runs, 
    year_count
  FROM home_runs
  WHERE yearid = 2016
    AND home_runs >= 1
)
, max_hr AS (
  SELECT
    playerid,
    MAX(home_runs) AS home_runs
  FROM home_runs
  GROUP BY 1
  HAVING MAX(home_runs) >= 1
)
SELECT DISTINCT 
  s.playerid, 
  s.name, 
  s.home_runs
FROM sixteen AS s
LEFT JOIN max_hr AS m
  ON s.playerid = m.playerid
  AND s.home_runs > m.home_runs
WHERE s.year_count >= 10





-- After finishing the above questions, here are some open-ended questions to consider.
-- **Open-ended questions**



-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.



-- 12. In this question, you will explore the connection between number of wins and attendance.
--     a. Does there appear to be any correlation between attendance at home games and number of wins?  


--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.




-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?








