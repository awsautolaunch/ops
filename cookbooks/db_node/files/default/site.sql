create database site;
\c site;
CREATE TABLE users(
   id  SERIAL PRIMARY KEY,
   firstname           TEXT      NOT NULL,
   lastname           TEXT      NOT NULL,
   AGE            INT       NOT NULL

);

