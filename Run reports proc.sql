CREATE PROCEDURE Run_reports 
AS

--Drop Table if this has already been run
IF OBJECT_ID('tempdb.dbo.#TempRatingRevenue') IS NOT NULL DROP TABLE #TempRatingRevenue

--(1) Revenue by ratings. Taking a look at a breakdown of what movie ratings generally make the most money.
SELECT DISTINCT m.content_rating,
	SUM(r.total_gross) OVER(PARTITION BY m.content_rating) as 'Rating_Revenue',
	SUM(r.total_gross) OVER() AS 'Total'
INTO #TempRatingRevenue
FROM Movies m
	JOIN RevTraktId r on r.trakt_id = m.trakt_id
WHERE m.content_rating IS NOT NULL

SELECT content_rating, 
	Rating_Revenue,
	Total,
	CONVERT(DOUBLE PRECISION, ROUND(Rating_Revenue * 100.0 / Total, 2)) AS '%'
FROM #TempRatingRevenue

--SELECT * FROM #TempRatingRevenue
--DROP TABLE #TempRatingRevenue


--(2) Revenue by theatrical release
--Going to generate a series of temp tables to make calculations on theater releases
--If they're already created, dropping them to allow new creation
IF OBJECT_ID('tempdb.dbo.#TheaterReleaseOccurences') IS NOT NULL DROP TABLE #TheaterReleaseOccurences
IF OBJECT_ID('tempdb.dbo.#TheaterReleaseGross') IS NOT NULL DROP TABLE #TheaterReleaseGross
IF OBJECT_ID('tempdb.dbo.#TheaterReleaseFinal') IS NOT NULL DROP TABLE #TheaterReleaseFinal

--Setting up brackets:
select r.release_type as 'Theater_Release_Size',
	count(1) as 'Number_of_Occurences'
into #TheaterReleaseOccurences
from (select case
		when theaters between 10 and 1210 then 'A Selective Release (10 - 1210)'
		when theaters between 1211 and 2410 then 'B Limited Release (1211 - 2410)'
		when theaters between 2411 and 3610 then 'C Semi-Nationwide Release (2411 - 3610)'
		when theaters between 3611 and 4810 then 'D Nationwide Release (3611 - 4810)'
		else '4810+' end as 'release_type'
		from RevTraktId) r
group by r.release_type

--Using same brackets to match up revenue
select	trakt_id,
		movie_title,
		total_gross,
		theaters,
		(case
		when theaters between 10 and 1210 then 'A Selective Release (10 - 1210)'
		when theaters between 1211 and 2410 then 'B Limited Release (1211 - 2410)'
		when theaters between 2411 and 3610 then 'C Semi-Nationwide Release (2411 - 3610)'
		when theaters between 3611 and 4810 then 'D Nationwide Release (3611 - 4810)'
		else '4810+' end) as 'release_type'
into #TheaterReleaseGross
from RevTraktId

--Various partitions to see the breakdowns by release_type, and make calc off of these numbers easier (profit per theatre)
select distinct o.Theater_Release_Size,
	o.Number_of_Occurences,
	SUM(g.theaters) OVER(PARTITION BY g.release_type) as 'Sum_#Theaters_In_Bracket',
	AVG(g.theaters) OVER(PARTITION BY g.release_type) as 'Avg#_Theaters_In_Bracket',
	SUM(g.total_gross) OVER(PARTITION BY g.release_type) as 'Theater_Release_Bracket_Gross'
into #TheaterReleaseFinal
from #TheaterReleaseGross g
	join #TheaterReleaseOccurences o on o.Theater_Release_Size = g.release_type

--The top end drives the most revenue, in large part b/c of huge outliers like Avengers: Endgame
select Theater_Release_Size, 
	Number_of_Occurences, 
	Avg#_Theaters_In_Bracket, 
	Theater_Release_Bracket_Gross, 
	(Theater_Release_Bracket_Gross / Sum_#Theaters_In_Bracket) as 'Gross per theatre in bracket'
from #TheaterReleaseFinal

/*
DROP TABLE #TempRatingRevenue
DROP TABLE #TheaterReleaseOccurences
DROP TABLE #TheaterReleaseGross
DROP TABLE #TheaterReleaseFinal
*/

--(3) Release Season vs Revenue
--Going to generate a series of temp tables to make calculations on different seasonal releases
--If they're already created, dropping them to allow new creation
IF OBJECT_ID('tempdb.dbo.#SeasonalReleaseOccurences') IS NOT NULL DROP TABLE #SeasonalReleaseOccurences
IF OBJECT_ID('tempdb.dbo.#SeasonalReleaseGross') IS NOT NULL DROP TABLE #SeasonalReleaseGross
IF OBJECT_ID('tempdb.dbo.#SeasonalReleaseFinal') IS NOT NULL DROP TABLE #SeasonalReleaseFinal

--Setting up brackets:
SELECT m.season_released as 'Season_Released',
	count(1) as 'Number_of_Release_In_Season'
into #SeasonalReleaseOccurences
FROM (SELECT CASE 
	WHEN MONTH(date_released) in (12, 1, 2) THEN 'Winter'
	WHEN MONTH(date_released) in (3, 4, 5) THEN 'Spring'
	WHEN MONTH(date_released) in (6, 7, 8) THEN 'Summer'
	WHEN MONTH(date_released) in (9, 10, 11) THEN 'Fall'
	ELSE 'Inconceivable!' END AS 'season_released'
	FROM Movies) m
GROUP BY m.Season_Released

--Using same brackets to match up revenue
select	m.trakt_id,
		m.title,
		r.total_gross,
		(CASE 
		WHEN MONTH(m.date_released) in (12, 1, 2) THEN 'Winter'
		WHEN MONTH(m.date_released) in (3, 4, 5) THEN 'Spring'
		WHEN MONTH(m.date_released) in (6, 7, 8) THEN 'Summer'
		WHEN MONTH(m.date_released) in (9, 10, 11) THEN 'Fall'
		ELSE 'Inconceivable!' END) as 'season_released'
into #SeasonalReleaseGross
from Movies m 
	JOIN RevTraktId r on r.trakt_id = m.trakt_id

--A partitions to see the breakdowns by season_released, and simplify viewing
select distinct o.Season_Released,
	o.Number_of_Release_In_Season,
	SUM(g.total_gross) OVER(PARTITION BY g.season_released) as 'Seasonal_Release_Bracket_Gross'
into #SeasonalReleaseFinal
from #SeasonalReleaseGross g
	join #SeasonalReleaseOccurences o on o.Season_Released = g.season_released

select Season_Released,
	Number_of_Release_In_Season,
	Seasonal_Release_Bracket_Gross,
	(Seasonal_Release_Bracket_Gross / Number_of_Release_In_Season) as 'Gross per release in seasonal bracket'
from #SeasonalReleaseFinal;

/*
DROP TABLE #SeasonalReleaseOccurences
DROP TABLE #SeasonalReleaseGross
DROP TABLE #SeasonalReleaseFinal
*/

/*
As far as I can tell, this function requires me to setup a Database Mail account, which doesn't seem to be available to me, at least on initial research.
EXEC msdb.dbo.sp_send_dbmail
	@account_name = 'Windows Admin',
	@description = 'Mail account for admin email',
	@email_address = 'tkelly364@gmail.com',
	@display_name = 'Movie Data Automated Mailer',
	@mailserver_name = 'smtp.gmail.com';
*/

--EXEC Run_reports;