CREATE TABLE
   IF NOT EXISTS USER (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      first_name VARCHAR(45) NOT NULL,
      last_name VARCHAR(45) NOT NULL,
      email VARCHAR(45) NOT NULL,
      username VARCHAR(45) NOT NULL,
      password VARCHAR(45) NOT NULL,
      regdate DATE NOT NULL,
      PRIMARY KEY (id)
   ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;