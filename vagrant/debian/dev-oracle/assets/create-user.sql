CREATE USER openxpki IDENTIFIED BY "openxpki"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT connect, resource TO openxpki;

QUIT;
