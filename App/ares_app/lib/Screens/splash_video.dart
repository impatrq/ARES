import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'login_screen.dart'; // Importamos tu pantalla de login

class SplashVideoScreen extends StatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Apunta exactamente a la carpeta y archivo que declaraste en pubspec.yaml
    _controller = VideoPlayerController.asset('assets/video_APP_inicio.mp4')
      ..initialize().then((_) {
        // Refrescamos y damos play
        setState(() {});
        _controller.play();
      });

    // Escuchamos cuando termina el video
    _controller.addListener(() {
      if (!_controller.value.isPlaying &&
          _controller.value.isInitialized &&
          (_controller.value.duration == _controller.value.position)) {
        
        // El video terminó -> Vamos al LoginScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para integrar con tu video
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            // Color rojo de ARES para el loader por si tarda un milisegundo en cargar
            : const CircularProgressIndicator(color: Color(0xFFA61C1C)), 
      ),
    );
  }
}