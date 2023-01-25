import 'package:flutter/material.dart';

class BasicScreen extends StatelessWidget {
  final Widget child;
  final String? title;

  const BasicScreen(this.child, {this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: title != null ? Text(title!) : null,
        ),
        body: child);
  }
}

class SearchInput extends StatefulWidget {
  final Function(String) onSubmit;

  const SearchInput(this.onSubmit, {super.key});

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  final _controller = TextEditingController();
  bool _cancel = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 120,
        child: TextField(
          controller: _controller,
          onSubmitted: (v) => _doSubmit(),
          onChanged: _onChanged,
          decoration: InputDecoration(
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              hintText: 'Search',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
              suffixIcon: IconButton(
                  icon: Icon(_cancel ? Icons.cancel : Icons.search),
                  onPressed: _cancel ? _doCancel : null)),
        ));
  }

  void _doSubmit() {
    //widget.onSubmit(_controller.text);
    //setState(() => _cancel = _controller.text.isNotEmpty);
  }

  void _onChanged(String value) {
    widget.onSubmit(_controller.text);
    setState(() => _cancel = _controller.text.isNotEmpty);
  }

  void _doCancel() {
    _controller.text = '';
    widget.onSubmit('');
    setState(() => _cancel = false);
  }
}
