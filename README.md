# ExpressでJWT認証を実装する

## 環境構築
```
npm init -y
```
パッケージの追加
```
npm install express mysql2 cors jsonwebtoken bcryptjs body-parser
```

MySQLのデータベースにusersテーブルを作成
```sql
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
```

## ファイル構成
nodemon.jsonを作成する。ローカルで簡易サーバーを起動しパナっしにできるように設定。
```json
{
  "watch": ["index.js"],
  "ext": "js",
  "ignore": ["node_modules"],
  "exec": "node index.js"
}
```

index.jsを作成する。こちらに認証のロジックを書く
```js
const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const bodyParser = require('body-parser');

const app = express();
const SECRET_KEY = "your-secret-key";  // 自分で選んだ秘密鍵

app.use(cors());
app.use(bodyParser.json());

// MySQLの接続情報
const db = mysql.createConnection({
  user: 'root',
  host: 'localhost',
  password: '1234',
  database: 'MyData',
  port: 3306,
});

// 新規登録
app.post('/register', async (req, res) => {
  const username = req.body.username;
  const password = bcrypt.hashSync(req.body.password, 8);  // パスワードをハッシュ化

  const query = "INSERT INTO users (username, password) VALUES (?, ?)";
  db.query(query, [username, password], (err, result) => {
    if (err) {
      res.status(500).send({ error: 'Error registering the user' });
    } else {
      res.status(200).send({ message: 'User registered' });
    }
  });
});

// ログイン
app.post('/login', (req, res) => {
  const query = "SELECT * FROM users WHERE username = ?";
  db.query(query, [req.body.username], (err, results) => {
    if (err) return res.status(500).send({ error: 'Error logging in' });

    const user = results[0];
    if (!user) return res.status(404).send({ message: 'User not found' });

    const passwordIsValid = bcrypt.compareSync(req.body.password, user.password);
    if (!passwordIsValid) return res.status(401).send({ message: 'Invalid password' });

    const token = jwt.sign({ id: user.id }, SECRET_KEY, { expiresIn: 86400 });  // 24時間有効なトークン
    res.status(200).send({ accessToken: token });
  });
});

// ユーザーの削除
app.delete('/delete', (req, res) => {
  const userId = req.body.userId;

  const query = "DELETE FROM users WHERE id = ?";
  db.query(query, [userId], (err, result) => {
    if (err) {
      res.status(500).send({ error: 'Error deleting the user' });
    } else {
      res.status(200).send({ message: 'User deleted' });
    }
  });
});

const port = 3001;
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
```