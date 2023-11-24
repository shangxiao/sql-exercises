insert into recycling (name, weight) values (
    (select name from site order by random() limit 1),
    (select (random() * 100)::int)
);

