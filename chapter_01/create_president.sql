create table president(
    last_name  varchar(15) not null,
    first_name varchar(15) not null,
    suffix     varchar(5) null,
    city       VARCHAR(20) NOT NULL,
    state      VARCHAR(2) NOT NULL,
    birth      DATE NOT NULL,
    death      DATE NULL
);