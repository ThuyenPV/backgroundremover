import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutterbackgroundremover/backgroundremover.dart';
import 'package:image_editor/image_editor.dart';
import 'package:image_picker/image_picker.dart' as ip;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? imageSelected;
  late ImageEditorController _editorController;
  late GlobalKey<ExtendedImageEditorState> editorGlobalKey;
  String? imageFromGallery;
  Uint8List? afterRemoveBackground;

  @override
  void initState() {
    _editorController = ImageEditorController();
    editorGlobalKey = GlobalKey<ExtendedImageEditorState>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            IconButton(
              onPressed: () async {
                final imageFile = await ip.ImagePicker().pickImage(
                  source: ip.ImageSource.gallery,
                );
                imageFromGallery = imageFile?.path;
                setState(() {});
              },
              icon: Icon(Icons.add_a_photo),
            ),
            if (imageFromGallery != null)
              ExtendedImage.file(
                File(imageFromGallery!),
                fit: BoxFit.contain,
                mode: ExtendedImageMode.editor,
                extendedImageEditorKey: editorGlobalKey,
                cacheRawData: true,
                initEditorConfigHandler: (state) {
                  return EditorConfig(
                    cropAspectRatio: 1.0,
                    maxScale: 4.0,
                    cropRectPadding: const EdgeInsets.all(20.0),
                    hitTestSize: 20.0,
                    initCropRectType: InitCropRectType.imageRect,
                    controller: _editorController,
                  );
                },
              )
            else
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Select an image to begin'),
              ),
            Visibility(
              visible: afterRemoveBackground != null,
              child: Image.memory(
                afterRemoveBackground!,
              ),
            ),
            IconButton(
              onPressed: () async {
                imageSelected = await onCropImage();
                if (imageSelected != null) {
                  final shouldRemoveBackground =
                      await showBackgroundRemovalDialog(context);
                  if (shouldRemoveBackground == true) {
                    final tempDir = await getTemporaryDirectory();
                    final tempFile =
                        await File('${tempDir.path}/temp_image.png')
                            .writeAsBytes(imageSelected!);

                    final res = await FlutterBackgroundRemover.removeBackground(
                      tempFile,
                    );
                    afterRemoveBackground = res;
                    setState(() {});

                    // if (context.mounted) {
                    //   GoRouter.of(context).pop(res);
                    // }

                    await tempFile.delete();
                  } else {
                    // if (context.mounted) {
                    //   GoRouter.of(context).pop(imageSelected);
                    // }
                  }
                }
              },
              icon: Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> showBackgroundRemovalDialog(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Do you want to remove background?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    child: const Text("Yes"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text("No"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List?> onCropImage() async {
    final ExtendedImageEditorState? state = editorGlobalKey.currentState;
    if (state == null) return null;

    final imgCropRect = state.getCropRect();
    final EditActionDetails action = state.editAction!;
    final double radian = action.rotateRadians;

    final bool flipHorizontal = action.flipY;
    final bool flipVertical = action.flipY;

    final currentImageSelected = state.rawImageData;
    final ImageEditorOption option = ImageEditorOption();

    option.addOption(ClipOption.fromRect(imgCropRect ?? Rect.zero));
    option.addOption(
        FlipOption(horizontal: flipHorizontal, vertical: flipVertical));
    if (action.hasRotateDegrees) {
      option.addOption(RotateOption(radian.toInt()));
    }

    // option.addOption(ColorOption.saturation(sat));
    // option.addOption(ColorOption.brightness(bright));
    // option.addOption(ColorOption.contrast(con));

    option.outputFormat = const OutputFormat.png(88);

    final result = await ImageEditor.editImage(
      image: currentImageSelected,
      imageEditorOption: option,
    );
    return result;
  }
}
