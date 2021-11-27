import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_assistant_client/event/update_bottom_item_num.dart';
import 'package:mobile_assistant_client/event/update_delete_btn_status.dart';
import 'package:mobile_assistant_client/model/video_folder_item.dart';
import 'package:mobile_assistant_client/network/device_connection_manager.dart';
import 'package:mobile_assistant_client/util/event_bus.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../model/ResponseEntity.dart';
import '../file_manager.dart';

class VideoFolderManagerPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _VideoFolderManagerState();
  }
}

class _VideoFolderManagerState extends State<VideoFolderManagerPage> with AutomaticKeepAliveClientMixin {
  bool _isLoadingCompleted = true;

  final _BACKGROUND_ALBUM_SELECTED = Color(0xffe6e6e6);
  final _BACKGROUND_ALBUM_NORMAL = Colors.white;

  final _ALBUM_NAME_TEXT_COLOR_NORMAL = Color(0xff515151);
  final _ALBUM_IMAGE_NUM_TEXT_COLOR_NORMAL = Color(0xff929292);

  final _ALBUM_NAME_TEXT_COLOR_SELECTED = Colors.white;
  final _ALBUM_IMAGE_NUM_TEXT_COLOR_SELECTED = Colors.white;

  final _BACKGROUND_ALBUM_NAME_NORMAL = Colors.white;
  final _BACKGROUND_ALBUM_NAME_SELECTED = Color(0xff5d87ed);

  final _OUT_PADDING = 20.0;
  final _IMAGE_SPACE = 15.0;

  List<VideoFolderItem> _selectedVideoFolders = [];
  List<VideoFolderItem> _videoFolders = [];

  final _URL_SERVER = "http://${DeviceConnectionManager.instance.currentDevice?.ip}:8080";

  late Function() _ctrlAPressedCallback;

  bool _isPageVisible = false;

  @override
  void initState() {
    super.initState();

    _ctrlAPressedCallback = () {
      if (_isPageVisible) {
        _setAllSelected();
      }

      debugPrint("Ctrl + A pressed...");
    };

    _addCtrlAPressedCallback(_ctrlAPressedCallback);

    _getAllVideoFolders((videos) {
      setState(() {
        _videoFolders = videos;
      });
    }, (error) {

    });
  }

  void _setAllSelected() {
    setState(() {
      _selectedVideoFolders.clear();
      _selectedVideoFolders.addAll(_videoFolders);
      updateBottomItemNum();
      _setDeleteBtnEnabled(true);
    });
  }

  bool _isControlDown() {
    FileManagerPage? fileManagerPage =
    context.findAncestorWidgetOfExactType<FileManagerPage>();
    return fileManagerPage?.state?.isControlDown() == true;
  }

  bool _isShiftDown() {
    FileManagerPage? fileManagerPage =
    context.findAncestorWidgetOfExactType<FileManagerPage>();
    return fileManagerPage?.state?.isShiftDown() == true;
  }

  void _addCtrlAPressedCallback(Function() callback) {
    FileManagerPage? fileManagerPage =
    context.findAncestorWidgetOfExactType<FileManagerPage>();
    fileManagerPage?.state?.addCtrlAPressedCallback(callback);
  }

  void _removeCtrlAPressedCallback(Function() callback) {
    FileManagerPage? fileManagerPage =
    context.findAncestorWidgetOfExactType<FileManagerPage>();
    fileManagerPage?.state?.addCtrlAPressedCallback(callback);
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xff85a8d0);
    const spinKit = SpinKitCircle(color: color, size: 60.0);

    Widget content = _createGridContent();

    return VisibilityDetector(
        key: Key("video_folder_manager"),
        child: GestureDetector(
          child: Stack(children: [
            content,
            Visibility(
              child: Container(child: spinKit, color: Colors.white),
              maintainSize: false,
              visible: !_isLoadingCompleted,
            )
          ],
            fit: StackFit.expand,
          ),
          onTap: () {
            _clearSelectedVideos();
          },
        ),
        onVisibilityChanged: (info) {
          setState(() {
            _isPageVisible = info.visibleFraction * 100 >= 100;
            if (_isPageVisible) {
              updateBottomItemNum();
            }
          });
        });
  }


  void _setVideoFolderSelected(VideoFolderItem videoFolder) {
    debugPrint("Shift key down status: ${_isShiftDown()}");
    debugPrint("Control key down status: ${_isControlDown()}");

    if (!_isContainsVideoFolder(_selectedVideoFolders, videoFolder)) {
      if (_isControlDown()) {
        setState(() {
          _selectedVideoFolders.add(videoFolder);
        });
      } else if (_isShiftDown()) {
        if (_selectedVideoFolders.length == 0) {
          setState(() {
            _selectedVideoFolders.add(videoFolder);
          });
        } else if (_selectedVideoFolders.length == 1) {
          int index = _videoFolders.indexOf(_selectedVideoFolders[0]);

          int current = _videoFolders.indexOf(videoFolder);

          if (current > index) {
            setState(() {
              _selectedVideoFolders = _videoFolders.sublist(index, current + 1);
            });
          } else {
            setState(() {
              _selectedVideoFolders = _videoFolders.sublist(current, index + 1);
            });
          }
        } else {
          int maxIndex = 0;
          int minIndex = 0;

          for (int i = 0; i < _selectedVideoFolders.length; i++) {
            VideoFolderItem current = _selectedVideoFolders[i];
            int index = _videoFolders.indexOf(current);
            if (index < 0) {
              debugPrint("Error image");
              continue;
            }

            if (index > maxIndex) {
              maxIndex = index;
            }

            if (index < minIndex) {
              minIndex = index;
            }
          }

          debugPrint("minIndex: $minIndex, maxIndex: $maxIndex");

          int current = _videoFolders.indexOf(videoFolder);

          if (current >= minIndex && current <= maxIndex) {
            setState(() {
              _selectedVideoFolders = _videoFolders.sublist(current, maxIndex + 1);
            });
          } else if (current < minIndex) {
            setState(() {
              _selectedVideoFolders = _videoFolders.sublist(current, maxIndex + 1);
            });
          } else if (current > maxIndex) {
            setState(() {
              _selectedVideoFolders = _videoFolders.sublist(minIndex, current + 1);
            });
          }
        }
      } else {
        setState(() {
          _selectedVideoFolders.clear();
          _selectedVideoFolders.add(videoFolder);
        });
      }
    } else {
      debugPrint("It's already contains this image, id: ${videoFolder.id}");

      if (_isControlDown()) {
        setState(() {
          _selectedVideoFolders.remove(videoFolder);
        });
      } else if (_isShiftDown()) {
        setState(() {
          _selectedVideoFolders.remove(videoFolder);
        });
      }
    }

    _setDeleteBtnEnabled(_selectedVideoFolders.length > 0);
    updateBottomItemNum();
  }

  void _clearSelectedVideos() {
    setState(() {
      _selectedVideoFolders.clear();
      updateBottomItemNum();
      _setDeleteBtnEnabled(false);
    });
  }

  void updateBottomItemNum() {
    eventBus.fire(UpdateBottomItemNum(_videoFolders.length, _selectedVideoFolders.length));
  }

  void _setDeleteBtnEnabled(bool enable) {
    eventBus.fire(UpdateDeleteBtnStatus(enable));
  }

  void updateDeleteBtnStatus() {
    _setDeleteBtnEnabled(_selectedVideoFolders.length > 0);
  }

  Widget _createGridContent() {
    final imageWidth = 140.0;
    final imageHeight = 140.0;
    final imagePadding = 3.0;

    return Container(
      child: GridView.builder(
        scrollDirection: Axis.vertical,
        physics: ScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            crossAxisSpacing: _IMAGE_SPACE,
            childAspectRatio: 1.0,
            mainAxisSpacing: _IMAGE_SPACE),
        controller: ScrollController(keepScrollOffset: true),
        itemBuilder: (BuildContext context, int index) {
          VideoFolderItem videoFolder = _videoFolders[index];

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                child: Container(
                  child: Stack(
                    children: [
                      Visibility(
                        child: RotationTransition(
                            turns: AlwaysStoppedAnimation(5 / 360),
                            child: Container(
                              width: imageWidth,
                              height: imageHeight,
                              padding: EdgeInsets.all(imagePadding),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: Color(0xffdddddd), width: 1.0),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3.0))),
                            )),
                        visible: videoFolder.videoCount > 1 ? true : false,
                      ),
                      Visibility(
                        child: RotationTransition(
                            turns: AlwaysStoppedAnimation(-5 / 360),
                            child: Container(
                              width: imageWidth,
                              height: imageHeight,
                              padding: EdgeInsets.all(imagePadding),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: Color(0xffdddddd), width: 1.0),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3.0))),
                            )),
                        visible: videoFolder.videoCount > 2 ? true : false,
                      ),
                      Container(
                        child: CachedNetworkImage(
                            imageUrl:
                                "${_URL_SERVER}/stream/video/thumbnail/${videoFolder.coverVideoId}/400/400"
                                    .replaceAll("storage/emulated/0/", ""),
                            fit: BoxFit.cover,
                            width: imageWidth,
                            height: imageWidth,
                            memCacheWidth: 400,
                            fadeOutDuration: Duration.zero,
                            fadeInDuration: Duration.zero),
                        padding: EdgeInsets.all(imagePadding),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: Color(0xffdddddd), width: 1.0),
                            borderRadius:
                                BorderRadius.all(Radius.circular(3.0))),
                      )
                    ],
                  ),
                  decoration: BoxDecoration(
                      color: _isContainsVideoFolder(_selectedVideoFolders, videoFolder)
                          ? _BACKGROUND_ALBUM_SELECTED
                          : _BACKGROUND_ALBUM_NORMAL,
                      borderRadius: BorderRadius.all(Radius.circular(4.0))),
                  padding: EdgeInsets.all(8),
                ),
                onTap: () {
                  setState(() {
                    _setVideoFolderSelected(videoFolder);
                  });
                },
                onDoubleTap: () {
                  // _currentAlbum = album;
                  // _tryToOpenAlbumImages(album.id);
                },
              ),
              GestureDetector(
                child: Container(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        videoFolder.name,
                        style: TextStyle(
                            inherit: false,
                            color: _isContainsVideoFolder(_selectedVideoFolders, videoFolder)
                                ? _ALBUM_NAME_TEXT_COLOR_SELECTED
                                : _ALBUM_NAME_TEXT_COLOR_NORMAL),
                      ),
                      Container(
                        child: Text(
                          "(${videoFolder.videoCount})",
                          style: TextStyle(
                              inherit: false,
                              color: _isContainsVideoFolder(_selectedVideoFolders, videoFolder)
                                  ? _ALBUM_IMAGE_NUM_TEXT_COLOR_SELECTED
                                  : _ALBUM_IMAGE_NUM_TEXT_COLOR_NORMAL),
                        ),
                        margin: EdgeInsets.only(left: 3),
                      )
                    ],
                  ),
                  margin: EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      color: _isContainsVideoFolder(_selectedVideoFolders, videoFolder)
                          ? _BACKGROUND_ALBUM_NAME_SELECTED
                          : _BACKGROUND_ALBUM_NAME_NORMAL),
                  padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                ),
                onTap: () {
                  setState(() {
                    // _setAlbumSelected(album);
                  });
                },
              )
            ],
          );
        },
        itemCount: _videoFolders.length,
        shrinkWrap: true,
      ),
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(_OUT_PADDING, _OUT_PADDING, _OUT_PADDING, 0),
    );
  }

  bool _isContainsVideoFolder(List<VideoFolderItem> folders, VideoFolderItem current) {
    for (VideoFolderItem folder in folders) {
      if (folder.id == current.id) return true;
    }

    return false;
  }

  void _getAllVideoFolders(Function(List<VideoFolderItem> videos) onSuccess,
      Function(String error) onError) {
    var url = Uri.parse("${_URL_SERVER}/video/folders");
    http.post(url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({}))
        .then((response) {
      if (response.statusCode != 200) {
        onError.call(response.reasonPhrase != null
            ? response.reasonPhrase!
            : "Unknown error");
      } else {
        var body = response.body;
        debugPrint("Get all videos list, body: $body");

        final map = jsonDecode(body);
        final httpResponseEntity = ResponseEntity.fromJson(map);

        if (httpResponseEntity.isSuccessful()) {
          final data = httpResponseEntity.data as List<dynamic>;

          onSuccess.call(data
              .map((e) => VideoFolderItem.fromJson(e as Map<String, dynamic>))
              .toList());
        } else {
          onError.call(httpResponseEntity.msg == null
              ? "Unknown error"
              : httpResponseEntity.msg!);
        }
      }
    }).catchError((error) {
      onError.call(error.toString());
    });
  }
  
  @override
  void dispose() {
    super.dispose();

    _removeCtrlAPressedCallback(_ctrlAPressedCallback);
  }

  @override
  bool get wantKeepAlive => true;
}
