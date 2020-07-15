CREATE PROCEDURE Data_clean
AS

--Only bad part of the revenue data is it doesn't come with any unique identifiers, so makes joining to main movie dataset tougher
--This first step is a really basic 'lemmatization' of high-grossing movie names, so joins will work better downstream
UPDATE Revenue SET movie_title = 'Star Wars: The Force Awakens' WHERE movie_title = 'Star Wars: Episode VII - The Force Awakens'
UPDATE Revenue SET movie_title = 'Star Wars: The Last Jedi' WHERE movie_title = 'Star Wars: Episode VIII - The Last Jedi'
UPDATE Revenue SET movie_title = 'Star Wars: The Rise of Skywalker' WHERE movie_title = 'Star Wars: Episode IX - The Rise of Skywalker'
UPDATE Revenue SET movie_title = 'Ocean''s Eight' WHERE movie_title = 'Ocean''s 8'
UPDATE Revenue SET movie_title = 'Pokémon Detective Pikachu' WHERE movie_title = 'Pok+¬mon Detective Pikachu'
--The elipses in this title is one character on the Movies table, switching it to the Revenue table version as it is three distinct period characters
UPDATE Movies SET title = 'Once Upon a Time... in Hollywood' WHERE title = 'Once Upon a Time… in Hollywood'

-- Since there are a few line items for some major releases (they made money in multiple years), 
-- I need to eliminate duplicate entries so as not to double-count them in other aggregates and make joins more seamless
-- Going to assign the highest-grossing year for each movie as the single entry, and will assign a trakt_id to it to make joins easy
-- Creating temp table to work with on this

IF OBJECT_ID('tempdb.dbo.#TempRevHighest') IS NOT NULL DROP TABLE #TempRevHighest

select distinct r.movie_title, 
	MAX(gross) OVER (PARTITION BY r.movie_title) AS 'Highest'
into #TempRevHighest
from revenue r

--DROP TABLE #TempRevHighest
--DROP TABLE RevTraktId
--select * from #TempRevHighest
--select * from Revenue
--select * from RevTraktId WHERE trakt_id IS NOT NULL

--Creating a non-temp table to be able to run queries afterwards on
--and so as not to touch the original landing revenue table
select NULL as 'trakt_id',
	r.movie_title as 'movie_title', 
	r.gross as 'gross',
	r.total_gross as 'total_gross',
	r.theaters as 'theaters',
	temp.Highest as 'highest'
into RevTraktId
from revenue r
	join #TempRevHighest temp on temp.movie_title = r.movie_title
where (r.movie_title = temp.movie_title AND r.gross = temp.Highest)

--Updating the trakt_ids, so joins/aggregates work on a 1-to-1 match
UPDATE RevTraktId
SET RevTraktId.trakt_id = movies.trakt_id
	FROM movies
WHERE movies.title = RevTraktId.movie_title;