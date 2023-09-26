-- Clearing empty columns at the end of the dataset, commented out afterword

--DECLARE @num INT = 27

--WHILE @num <> 66
--BEGIN
--    DECLARE @columnName NVARCHAR(MAX)
--    SET @columnName = 'F' + CAST(@num AS NVARCHAR(MAX))

--    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'CovidDeaths2023' AND COLUMN_NAME = @columnName)
--    BEGIN
--        DECLARE @sql NVARCHAR(MAX)
--        SET @sql = 'ALTER TABLE CovidDeaths2023 DROP COLUMN ' + QUOTENAME(@columnName)
--        EXEC sp_executesql @sql
--    END

--    SET @num = @num + 1
--END

--Looking at the entire dataset

SELECT * 
FROM COVIDProject2..CovidVaccinations2023
Order by 3, 4

--The data that will be used 
SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM COVIDProject2..CovidDeaths2023 dea
ORDER BY 1, 2

-- Looking at Total Cases vs Total Deaths
SELECT Location, date, total_cases, total_deaths, (cast(total_deaths as float)/total_cases)*100 as DeathChanceOnceInfected
FROM COVIDProject2..CovidDeaths2023 dea
Where continent = 'North America'
ORDER BY 1, 2

--Looking at Highest Average Death Chance by Country
SELECT Location, AVG((cast(total_deaths as float)/total_cases)*100) as DeathChanceOnceInfected
FROM COVIDProject2..CovidDeaths2023 dea
Group by location
ORDER BY 1, 2

--Looking at Total Cases vs Population
SELECT Location, date, total_cases, population, (total_cases/population)*100 as InfectedPopulation
FROM COVIDProject2..CovidDeaths2023 dea
Where location like 'canada'
ORDER BY 1, 2

--Looking at Highest Recorded Unique COVID cases 
SELECT Location, MAX((total_cases/population)*100) as PercentInfectedPopulation
FROM COVIDProject2..CovidDeaths2023 dea
Group by location
ORDER BY 1, 2

-- Looking at Countries with Highest Death Counts
SELECT Location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM COVIDProject2..CovidDeaths2023 dea
Where continent IS NOT NULL
Group by Location
order by TotalDeathCount desc

-- Broken down by continent and income
SELECT location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM COVIDProject2..CovidDeaths2023 dea
Where continent is null
Group by location
order by TotalDeathCount desc

-- Global Numbers
SELECT
    SUM(new_cases) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths, 
    CASE WHEN SUM(new_cases) = 0 THEN 0 ELSE SUM(CAST(new_deaths AS INT)) / SUM(new_cases) END * 100 AS DeathPercentage
FROM COVIDProject2..CovidDeaths2023 dea
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1, 2

-- Total Numbers as of September 13th, 2023
SELECT SUM(new_cases) as total_cases , SUM(cast(new_deaths as float)) as total_deaths, SUM(cast(new_deaths as float))/SUM(new_cases) * 100 as DeathPercentage--, total_deaths, (total_deaths/total_cases)*100 as DeathChanceOnceInfected
FROM COVIDProject2..CovidDeaths2023 dea
Where continent is not null
ORDER BY 1, 2

-- Examining Total Population vs Vaccinations

-- Using CTE
With PopvsVac (Continent, Location, Date, Population, New_vaccinations, RollingPeopleVaccinated)
as 
(

Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(cast(vac.new_vaccinations as float)) OVER (Partition by dea.location order by dea.location, 
dea.date) as RollingPeopleVaccinated
From COVIDProject2..CovidDeaths2023 dea
Join COVIDProject2..CovidVaccinations2023 vac
	On dea.location = vac.location 
	and dea.date = vac.date
Where dea.continent is not null 
)

Select *, (RollingPeopleVaccinated/Population) *100 as PercentPopVaccinated
From PopvsVac

-- Same thing using Temp Table

DROP Table if exists #PercentPopVaccinated
Create Table #PercentPopVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccination numeric,
RollingPeopleVaccinated numeric,
)
Insert into #PercentPopVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(cast(vac.new_vaccinations as float)) OVER (Partition by dea.location order by dea.location, 
dea.date) as RollingPeopleVaccinated

From COVIDProject2..CovidDeaths2023 dea
Join COVIDProject2..CovidVaccinations2023 vac
	On dea.location = vac.location 
	and dea.date = vac.date
Where dea.continent is not null 

--GDP per Capita vs Death Percentage

SELECT dea.location, vac.gdp_per_capita, SUM(cast(dea.new_deaths as float))/SUM(dea.new_cases) * 100 as DeathPercentage
FROM COVIDProject2..CovidDeaths2023 dea
JOIN COVIDProject2..CovidVaccinations2023 vac
    ON dea.location = vac.location 
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.location, vac.gdp_per_capita
ORDER by 2, 3

--Percent of Population aged 65 or older vs Percentage of Population Dead due to Covid

SELECT 
    dea.location, 
    vac.aged_65_older,  
   CASE 
        WHEN SUM(cast(dea.new_deaths as float)) = 0 
        THEN 0 
        ELSE SUM(cast(dea.new_deaths as float))/SUM(dea.new_cases) * 100 
    END as DeathPercentage
FROM COVIDProject2..CovidDeaths2023 dea
JOIN COVIDProject2..CovidVaccinations2023 vac
	ON dea.location = vac.location 
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.location, vac.aged_65_older
ORDER by 2, 3

--Creating Views

--View for Percent of Population Vaccinated 

USE COVIDProject2
GO
CREATE VIEW PercentPopVaccinated AS
SELECT
    dea.location,
    ISNULL(dea.population, 0) AS Population,
	CASE
		WHEN ISNULL(MAX(CAST(people_fully_vaccinated_per_hundred as float)),0) > 100
		THEN 100
		ELSE ISNULL(MAX(CAST(people_fully_vaccinated_per_hundred as float)),0)
	END as FullyVaccinatedPercentage
FROM COVIDProject2..CovidDeaths2023 dea
JOIN COVIDProject2..CovidVaccinations2023 vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
Group by dea.location, dea.population

--View for death count by continent

USE COVIDProject2
GO
Create View DeathCountByContinent as 
SELECT continent, ISNULL(MAX(cast(total_deaths as int)),0) as TotalDeathCount
FROM COVIDProject2..CovidDeaths2023
Where continent IS NOT NULL
Group by continent

--View for percentage pop infected by country

USE COVIDProject2
GO
Create View NEWPercentPopulationInfectedByCountry as 
SELECT Location, ISNULL(MAX(total_cases),0) as HighestInfectionCount, ISNULL(population,0) as Population, ISNULL(MAX((total_cases/population))*100,0) as PercentPopulationInfected
FROM COVIDProject2..CovidDeaths2023
Group by Location, population

--View for percentage pop infected by country and datte

USE COVIDProject2
GO
Create View DATEPercentPopulationInfectedByCountry as 
SELECT Location, date, ISNULL(MAX(total_cases),0) as HighestInfectionCount, ISNULL(population,0) as Population, ISNULL(MAX((total_cases/population))*100,0) as PercentPopulationInfected
FROM COVIDProject2..CovidDeaths2023
WHERE date < '2023-09-01'
Group by Location, population, date

--View for GDP per Capita vs Death Percentage

USE COVIDProject2
GO
Create View GDPvsDeathPercentage as
SELECT dea.location, ISNULL(vac.gdp_per_capita,0) as gdp_per_capita, ISNULL(SUM(cast(dea.new_deaths as float))/SUM(dea.new_cases) * 100,0) as DeathPercentage
FROM COVIDProject2..CovidDeaths2023 dea
JOIN COVIDProject2..CovidVaccinations2023 vac
    ON dea.location = vac.location 
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.location, vac.gdp_per_capita

--View for numbers broken down by continent and income

USE COVIDProject2
GO
Create View ContinentAndIncome as
SELECT location, ISNULL(MAX(cast(total_deaths as int)),0) as TotalDeathCount
FROM COVIDProject2..CovidDeaths2023 dea
Where continent is null
Group by location

--View for Percent of Population aged 65 or older vs Percentage of Population Dead due to Covid

USE COVIDProject2
GO
Create View PopSixtyFivePlusvsPercentDead as
SELECT 
    dea.location, 
    ISNULL(vac.aged_65_older, 0) as aged_65_older,  
   CASE 
        WHEN SUM(cast(dea.new_deaths as float)) = 0 OR SUM(cast(dea.new_deaths as float)) IS NULL
        THEN 0 
        ELSE ISNULL(SUM(cast(dea.new_deaths as float))/SUM(dea.new_cases) * 100, 0)
    END as DeathPercentage
FROM COVIDProject2..CovidDeaths2023 dea
JOIN COVIDProject2..CovidVaccinations2023 vac
	ON dea.location = vac.location 
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.location, vac.aged_65_older

--View for Updated Global Numbers

USE COVIDProject2
GO
Create View GlobalCasesAndDeaths as
Select ISNULL(SUM(new_cases),0) as total_cases, ISNULL(SUM(cast(new_deaths as int)),0) as total_deaths, ISNULL(SUM(cast(new_deaths as int))/SUM(New_Cases)*100,0) as DeathPercentage
From COVIDProject2..CovidDeaths2023
where continent is not null 


