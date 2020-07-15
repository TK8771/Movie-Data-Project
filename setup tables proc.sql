--This procedure with setup the landing tables for the data that will eventually come from the json/csv files created in Python
CREATE PROCEDURE Setup_Tables
AS

CREATE TABLE Movies (
	trakt_id int primary key,
	imdb_id varchar(20),
	title varchar(max),
	date_released date,
	year_released int,
	country char,
	content_rating varchar(10),
	watch_count int,
	rating float,
	votes int)

--DROP TABLE Movies

CREATE TABLE Revenue (
	movie_title varchar(max),
	gross bigint,
	total_gross bigint,
	theaters int);

--DROP TABLE Revenue
--DROP TABLE RevTraktId

--EXEC Setup_Tables;