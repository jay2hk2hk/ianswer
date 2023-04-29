import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final _databaseName = "MyDatabase.db";
  static final _databaseVersion = 1;

  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async =>
      // lazily instantiate the db the first time it is accessed
      _database ??= await _initDatabase();
  //return _database;

  // this opens the database and creates it if it doesn't exist
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    // SQL code to create  table
    await db.execute(
        '''  
        CREATE TABLE chat (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chatname TEXT NOT NULL
         )''');
    // SQL code to create  table
    await db.execute(
        '''  
        CREATE TABLE chat_detail (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chat_id INTEGER NOT NULL,    
          detail TEXT NOT NULL,  
          is_user INTEGER NOT NULL,  
          FOREIGN KEY (chat_id) REFERENCES chat (id)                  
           ON DELETE NO ACTION ON UPDATE NO ACTION
         )''');
  }

  // Inserting and updating a user
  Future<Chat> upsertChat(Chat user) async {
    Database db = await instance.database;
    var count = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM chat WHERE chatname = ?", [user.chatname]));
    if (count == 0) {
      user.id = await db.insert("chat", user.toMap());
    } else {
      await db
          .update("chat", user.toMap(), where: "id = ?", whereArgs: [user.id]);
    }
    return user;
  }

  // Inserting and updating a blog
  Future<ChatDetail> upsertChatDetail(ChatDetail blog) async {
    Database db = await instance.database;
    var count = Sqflite.firstIntValue(await db
        .rawQuery("SELECT COUNT(*) FROM chat_detail WHERE id = ?", [blog.id]));
    if (count == 0) {
      await db.insert("chat_detail", blog.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update("chat_detail", blog.toMap(),
          where: "id = ?", whereArgs: [blog.id]);
    }
    return blog;
  }

  // fetch a single user
  Future<Chat> fetchChat(int id) async {
    Database db = await instance.database;
    List<Map> results =
        await db.query("chat", where: "id = ?", whereArgs: [id]);

    Chat user = Chat.fromMap(results[0]);
    return user;
  }

  // fetch a all user
  Future<List<Chat>> fetchChats() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results = await db.query("chat");

    List<Chat> blogs = [];
    results.forEach((result) {
      Chat blog = Chat.fromMap(result);
      blogs.add(blog);
    });
    return blogs;
  }

  // fetch a single blog
  Future<ChatDetail> fetchChatDetail(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results =
        await db.query("chat_detail", where: "id = ?", whereArgs: [id]);

    ChatDetail blog = ChatDetail.fromMap(results[0]);
    return blog;
  }

  // fetch list of all the blogs
  Future<List<ChatDetail>> fetchChatDetails() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results = await db.query("chat_detail");

    List<ChatDetail> blogs = [];
    results.forEach((result) {
      ChatDetail blog = ChatDetail.fromMap(result);
      blogs.add(blog);
    });
    return blogs;
  }

  // fetch ChatDetail of a particular user
  Future<List<ChatDetail>> fetchChatDetailsByChatId(int chat_id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results = await db
        .query("chat_detail", where: "chat_id = ?", whereArgs: [chat_id]);

    List<ChatDetail> chatDetails = [];
    results.forEach((result) {
      ChatDetail chatDetail = ChatDetail.fromMap(result);
      chatDetails.add(chatDetail);
    });
    return chatDetails;
  }

  // delete a ChatDetail
  Future<int> deleteChatDetail(int id) async {
    Database db = await instance.database;
    return await db.delete("chat_detail", where: "id = ?", whereArgs: [id]);
  }
}

class Chat {
  int? id;
  String chatname;

  Chat({required this.chatname});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatname': chatname,
    };
  }

  Chat.fromMap(Map<dynamic, dynamic> item)
      : id = item["id"],
        chatname = item["chatname"];
}

class ChatDetail {
  int? id;
  int chat_id;
  String detail;
  int is_user;
  ChatDetail(
      {required this.id,
      required this.chat_id,
      required this.detail,
      required this.is_user});

  Map<String, dynamic> toMap() {
    return {'id': id, 'chat_id': chat_id, 'detail': detail, 'is_user': is_user};
  }

  ChatDetail.fromMap(Map<String, dynamic> item)
      : id = item["id"],
        chat_id = item["chat_id"],
        detail = item["detail"],
        is_user = item["is_user"];
}
