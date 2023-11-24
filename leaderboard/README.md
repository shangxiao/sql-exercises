Generating a Top 5 Leaderboard with Other Category
==================================================


The Data
--------

```
python_exercises=# table recycling;
  name   | weight
---------+--------
 Site 9  |     42
 Site 2  |     33
 Site 7  |     72
 Site 3  |     64
 Site 4  |     74
 Site 9  |     63
 Site 3  |     60
 Site 5  |      8
 Site 3  |     57
 Site 10 |     54
 Site 6  |     11
 Site 2  |     36
 Site 3  |     76
 Site 8  |     62
 Site 1  |     61
 Site 10 |      8
 Site 8  |     56
 Site 5  |     44
 Site 1  |     94
 Site 9  |     94
(20 rows)
```



Step 1: Sum Weights, Group by Site, Order by Total Weight
---------------------------------------------------------

```
python_exercises=# select name, sum(weight) as total from recycling group by name order by total desc;
  name   | sum
---------+-----
 Site 3  | 257
 Site 9  | 199
 Site 1  | 155
 Site 8  | 118
 Site 4  |  74
 Site 7  |  72
 Site 2  |  69
 Site 10 |  62
 Site 5  |  52
 Site 6  |  11
(10 rows)
```


Optional Step Add Grand Total
-----------------------------

Grouping sets / rollups are useful for generating subtotals for defined groups.

```
python_exercises=# select name, sum(weight) as total from recycling group by ROLLUP (name) order by total desc;
  name   | sum
---------+------
 NULL!   | 1069
 Site 3  |  257
 Site 9  |  199
 Site 1  |  155
 Site 8  |  118
 Site 4  |   74
 Site 7  |   72
 Site 2  |   69
 Site 10 |   62
 Site 5  |   52
 Site 6  |   11
(11 rows)
```


Step 2: Add a row number
------------------------

Defining a row number allows us to setup conditionals to know when to keep the top 5 or group the remaining by an
"other" category.

```
python_exercises=# select
    ROW_NUMBER() over (),
    *
from (
    select
        name, sum(weight) as total
    from recycling
    group by rollup (name)
    order by total desc
) t;
 row_number |  name   | total
------------+---------+-------
          1 | NULL!   |  1069
          2 | Site 3  |   257
          3 | Site 9  |   199
          4 | Site 1  |   155
          5 | Site 8  |   118
          6 | Site 4  |    74
          7 | Site 7  |    72
          8 | Site 2  |    69
          9 | Site 10 |    62
         10 | Site 5  |    52
         11 | Site 6  |    11
(11 rows)
```


Step 3: Conditional expression
------------------------------

Use a conditional expression to define the "Other" category name.

```
python_exercises=# select
    case
        when row_number <= 6 then name
        else 'Other'
    end as name,
    total
from (
    select
        ROW_NUMBER() over (),
        *
    from (
        select
            name, sum(weight) as total
        from recycling
        group by rollup (name)
        order by total desc
    ) t
) t2;
  name  | total
--------+-------
 NULL!  |  1069
 Site 3 |   257
 Site 9 |   199
 Site 1 |   155
 Site 8 |   118
 Site 4 |    74
 Other  |    72
 Other  |    69
 Other  |    62
 Other  |    52
 Other  |    11
(11 rows)
```


Step 4: Regroup by Name
-----------------------

 - A second regrouping of data is required to get the total for the 'Other' category.
 - Note that you must pass through the row number so that you can preserve desired ordering.

```
python_exercises=# select
    name,
    sum(total) as group_total
from (
    select
        case
            when row_number <= 6 then name
            else 'Other'
        end as name,
        case
            when row_number <= 6 then row_number
            else 7
        end as row_number,
        total
    from (
        select
            row_number() over (),
            *
        from (
            select
                name, sum(weight) as total
            from recycling
            group by rollup (name)
            order by total desc
        ) t
    ) t2
) t3
group by name, row_number
order by row_number;
  name  | group_total
--------+-------------
 NULL!  |        1069
 Site 3 |         257
 Site 9 |         199
 Site 1 |         155
 Site 8 |         118
 Site 4 |          74
 Other  |         266
(7 rows)
```


Optional Step: Keep report rows at a consistent size
----------------------------------------------------

Use the window function `lead(false, 1, true)` to set an `is_last` flag then use that to optionally setup the "Other"
category.  `lead()` evaulates _upcoming_ rows in the window partition. The 3rd argument is a default – the last row
would have no leads therefore the default would be evaluated.

ref: https://www.postgresql.org/docs/current/functions-window.html


```
python_exercises=# select
    name,
    sum(total) as group_total
from (
    select
        case
            when row_number <= 6 then name
            when row_number = 7 and is_last then name
            else 'Other'
        end as name,
        case
            when row_number <= 6 then row_number
            else 7
        end as row_number,
        total
    from (
        select
            row_number() over (),
            lead(false, 1, true) over () as is_last,
            *
        from (
            select
                name, sum(weight) as total
            from recycling
            group by rollup (name)
            order by total desc
        ) t
    ) t2
) t3
group by name, row_number
order by row_number;
  name  | group_total
--------+-------------
 NULL!  |        1069
 Site 3 |         257
 Site 9 |         199
 Site 1 |         155
 Site 8 |         118
 Site 4 |          74
 Other  |         266
(7 rows)
```

then deleting sites other than the top 7

```
python_exercises=# delete from recycling where name in ('Site 2', 'Site 10', 'Site 5', 'Site 6');
DELETE 7
```

```
python_exercises=# select
    name,
    sum(total) as group_total
from (
    select
        case
            when row_number <= 6 then name
            when row_number = 7 and is_last then name
            else 'Other'
        end as name,
        case
            when row_number <= 6 then row_number
            else 7
        end as row_number,
        total
    from (
        select
            row_number() over (),
            lead(false, 1, true) over () as is_last,
            *
        from (
            select
                name, sum(weight) as total
            from recycling
            group by rollup (name)
            order by total desc
        ) t
    ) t2
) t3
group by name, row_number
order by row_number;
  name  | group_total
--------+-------------
 NULL!  |         875
 Site 3 |         257
 Site 9 |         199
 Site 1 |         155
 Site 8 |         118
 Site 4 |          74
 Site 7 |          72
(7 rows)
```
