-- usersテーブルを
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL
);

-- usersテーブルのデータを取得
SELECT * FROM users;

--ダミーのユーザー情報を入れておくと良さそう
INSERT INTO users (username, password) VALUES ('田中太郎', '1234abcd');
INSERT INTO users (username, password) VALUES ('Tom', 'abcd');