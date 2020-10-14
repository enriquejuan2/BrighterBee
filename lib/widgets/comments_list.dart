import 'dart:io';

import 'package:brighter_bee/widgets/comment_widget.dart';
import 'package:brighter_bee/widgets/replies_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/subjects.dart';

class CommentsList extends StatefulWidget {
  String community;
  String postKey;
  String username;

  CommentsList(this.community, this.postKey, this.username);

  @override
  _CommentsList createState() => _CommentsList(community, postKey, username);
}

class _CommentsList extends State<CommentsList> {
  String community;
  String key;
  String username;

  CommentListBloc commentListBloc;
  ScrollController controller = ScrollController();

  _CommentsList(this.community, this.key, this.username);

  @override
  void initState() {
    super.initState();
    commentListBloc = CommentListBloc(community, key);
    commentListBloc.fetchFirstList();
    controller.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (controller.offset >= controller.position.maxScrollExtent &&
        !controller.position.outOfRange) {
      print("At the end of list");
      commentListBloc.fetchNextComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: commentListBloc.commentStream,
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return ListView.builder(
            itemCount: snapshot.data.length,
            shrinkWrap: true,
            controller: controller,
            itemBuilder: (context, index) {
              debugPrint('NSP');
              return ExpansionTile(
                backgroundColor: Color.fromRGBO(204, 204, 204, 0.5),
                title: CommentWidget(
                    snapshot.data[index]['community'],
                    snapshot.data[index]['parentPost'],
                    snapshot.data[index]['commKey'],
                    snapshot.data[index]['parent'],
                    username,
                    false),
                children: [
                  Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 15),
                      child: RepliesList(
                          snapshot.data[index]['community'],
                          snapshot.data[index]['parentPost'],
                          snapshot.data[index]['commKey'],
                          username))
                ],
              );
            },
          );
        } else {
          return CircularProgressIndicator();
        }
      },
    );
  }
}

class CommentListBloc {
  String community;
  String key;

  bool showIndicator = false;
  List<DocumentSnapshot> documentList;
  BehaviorSubject<bool> showIndicatorController;
  BehaviorSubject<List<DocumentSnapshot>> commentController;

  CommentListBloc(this.community, this.key) {
    commentController = BehaviorSubject<List<DocumentSnapshot>>();
  }

  Stream<List<DocumentSnapshot>> get commentStream => commentController.stream;

/*This method will automatically fetch first 10 elements from the document list */
  Future fetchFirstList() async {
    try {
      documentList = (await FirebaseFirestore.instance
              .collection("communities/$community/posts/$key/comments")
              .orderBy("upvotes", descending: true)
              .limit(10)
              .get())
          .docs;
      print(documentList);
      commentController.sink.add(documentList);
    } on SocketException {
      commentController.sink
          .addError(SocketException("No Internet Connection"));
    } catch (e) {
      print(e.toString());
      commentController.sink.addError(e);
    }
  }

/*This will automatically fetch the next 10 elements from the list*/
  fetchNextComments() async {
    try {
      updateIndicator(true);
      List<DocumentSnapshot> newDocumentList = (await FirebaseFirestore.instance
          .collection("communities/$community/posts/$key/comments")
          .orderBy("upvotes", descending: true)
          .startAfterDocument(documentList[documentList.length - 1])
          .limit(10)
          .get())
          .docs;
      documentList.addAll(newDocumentList);
      commentController.sink.add(documentList);
    } on SocketException {
      commentController.sink
          .addError(SocketException("No Internet Connection"));
    } catch (e) {
      print(e.toString());
      commentController.sink.addError(e);
    }
  }

  updateIndicator(bool value) async {
    showIndicator = value;
    showIndicatorController.sink.add(value);
  }

  void dispose() {
    commentController.close();
    showIndicatorController.close();
  }
}
