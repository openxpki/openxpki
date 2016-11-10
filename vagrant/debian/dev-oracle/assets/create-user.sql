DROP USER %user%;

CREATE USER %user% IDENTIFIED BY "%password%"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT connect, resource TO %user%;

QUIT;
