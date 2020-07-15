--Raw data upload procedure
CREATE PROCEDURE Raw_data_upload
AS

--Loading the Revenue data from csv
BULK INSERT Revenue
	FROM 'C:\Users\Owner\Documents\Movie_project\movie_rev.csv'
	WITH
	(
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	BATCHSIZE = 1,
	MAXERRORS = 1,
	FIRSTROW = 2)



--Declare and load the json
DECLARE @JSON VARCHAR(MAX)

SELECT @JSON = BulkColumn
FROM OPENROWSET (BULK 'C:\Users\Owner\Documents\Movie_project\movie_data.json', SINGLE_CLOB) 
as j;

--Conditional statement to load the data if new data is added, or to update if not current.
MERGE INTO Movies AS M
USING (
    SELECT *
    FROM  OPENJSON(@JSON)
          WITH (trakt_id int '$.movie.ids.trakt',
	imdb_id varchar(20) '$.movie.ids.imdb',
	title varchar(max) '$.movie.title',
	date_released date '$.movie.released',
	year_released int '$.movie.year',
	country char '$.movie.country',
	content_rating varchar(10) '$.movie.certification',
	watch_count int '$.watcher_count',
	rating float '$.movie.rating',
	votes int '$.movie.votes')) InputJSON
   ON M.trakt_id = InputJSON.trakt_id
WHEN MATCHED THEN
    UPDATE SET M.trakt_id = InputJSON.trakt_id,
               M.imdb_id = InputJSON.imdb_id,
               M.title = InputJSON.title,
			   M.date_released = inputJSON.date_released,
               M.year_released = InputJSON.year_released,
			   M.country = InputJSON.country,
			   M.content_rating = InputJSON.content_rating,
               M.watch_count = InputJSON.watch_count,
               M.rating = InputJSON.rating,
               M.votes = InputJSON.votes
WHEN NOT MATCHED THEN
    INSERT (trakt_id, imdb_id, title, date_released, year_released, country, content_rating, watch_count, rating, votes)
    VALUES (InputJSON.trakt_id, InputJSON.imdb_id, InputJSON.title, InputJSON.date_released, InputJSON.year_released, InputJSON.country, InputJSON.content_rating, InputJSON.watch_count, InputJSON.rating, InputJSON.votes);

--EXEC Raw_data_upload;