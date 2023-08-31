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

## JWT認証の仕組みについて
JWT認証の仕組みは以下のようになっている。
1. ユーザーがログインすると、サーバーはJWTを生成する。
2. ユーザーがリクエストを送信すると、JWTを含める。
3. サーバーはJWTを検証し、ユーザーにレスポンスを返す。
4. ユーザーはJWTを保存し、次回のリクエストに含める。
5. サーバーはJWTを検証し、ユーザーにレスポンスを返す。
6. ユーザーがログアウトすると、JWTを削除する。

## クライアントについて
今回は、Flutterを使用するので、shared_preferencesを使用して、ログイン情報を保存する。
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_auth/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  Future<void> login() async {
    final response = await http.post(
      Uri.parse('http://localhost:3001/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': nameController.text,
        'password': passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      print("Response data: $responseData");

      if (responseData['accessToken'] != null) {  // ここを'accessToken'に変更
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['accessToken'] as String); // ここも'accessToken'に変更
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        print('Login Success');
      } else if (responseData['message'] != null) {
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(responseData['message'] as String),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        print('Login Error: Unexpected response'); // エラーメッセージを追加
      }
    } else {
      print('HTTP Error with code: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: login,
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## ログインの維持
main.dartのコードを以下のように変更する。
```dart
import 'package:flutter/material.dart';
import 'package:jwt_auth/home_page.dart';
import 'package:jwt_auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 追加
  SharedPreferences prefs = await SharedPreferences.getInstance();
  var token = prefs.getString('token');
  runApp(MyApp(token: token));
}

class MyApp extends StatelessWidget {
  final String? token;

  MyApp({Key? key, this.token}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: token == null ? LoginPage() : HomePage(),
    );
  }
}
```