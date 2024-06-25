// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:signals/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const baseUrl = 'https://superflixapi.top/';

const filmesName = 'filmes';
const serieName = 'series';
const tvName = 'tv';

var defaultType = filmesName.toSignal();
var currentPage = 1.toSignal();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const Home(),
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListTile(
              title: const Text('Filmes'),
              onTap: () {
                defaultType.value = filmesName;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Search(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Series'),
              onTap: () {
                defaultType.value = serieName;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Search(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('TV'),
              onTap: () {
                defaultType.value = tvName;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Search(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  bool loading = false;
  final searchController = TextEditingController();
  List<Map<String, dynamic>> itens = [];

  @override
  void initState() {
    super.initState();
    search();
  }

  Future search() async {
    itens.clear();
    loading = true;
    setState(() {});
    var query = '';

    if (searchController.text.isNotEmpty) {
      query = '?search=${searchController.text}';
    }
    var resp = await Dio().getUri(Uri.parse(baseUrl + defaultType.value + query),
        options: Options(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Credentials': 'true',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Allow-Methods': 'GET,PUT,POST,DELETE'
        }));
    var body = parse(resp.data);

    var htmlItens = body.querySelectorAll('.items_listing .item');
    log(htmlItens.length.toString());

    for (var item in htmlItens) {
      var title = item.querySelector('.title')?.text;
      var link = item.querySelector('.actions .open')?.attributes['href'];

      itens.add({
        'title': title!.substring(8, title.length - 1),
        'link': link,
        'type': defaultType.value,
      });
    }

    log(itens.first['link']);

    loading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(defaultType.watch(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: searchController,
                    //outlinedborder
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      hintText: 'Search',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                GestureDetector(
                  onTap: search,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                    ),
                  ),
                )
              ],
            ),
            Expanded(
              child: Builder(builder: (context) {
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      onTap: () async {
                        if (defaultType.value == serieName) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SerieEpSelect(
                                name: itens[index]['title'],
                                link: itens[index]['link'],
                              ),
                            ),
                          );
                        }
                        if (defaultType.value == filmesName) {
                          var resp = await Dio().get(itens[index]['link']);
                          var body = parse(resp.data);

                          var videoId = body.querySelector('.player_select_item')?.attributes['data-id'];
                          if (videoId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Video not found'),
                              ),
                            );
                            launchUrl(Uri.parse(itens[index]['link']));

                            return;
                          }

                          var player = await Dio().post(
                            'https://superflixapi.top/api',
                            data: FormData.fromMap(
                              {
                                'action': 'getPlayer',
                                'video_id': videoId,
                              },
                            ),
                          );

                          var playerURL = player.data['data']['video_url'];
                          launchUrl(Uri.parse(playerURL));
                        }
                        if (defaultType.value == tvName) {
                          launchUrl(Uri.parse(itens[index]['link']));
                        }
                      },
                      title: Text(itens[index]['title']),
                    );
                  },
                );
              }),
            )
          ],
        ),
      ),
    );
  }
}

class SerieEpSelect extends StatefulWidget {
  const SerieEpSelect({super.key, required this.link, required this.name});

  final String name;
  final String link;

  @override
  State<SerieEpSelect> createState() => _SerieEpSelectState();
}

class _SerieEpSelectState extends State<SerieEpSelect> {
  List<Map<String, dynamic>> itens = [];

  bool loading = true;

  Future getTempsAndEps() async {
    itens.clear();
    loading = true;
    if (mounted) setState(() {});

    var resp = await Dio().get(widget.link);
    var body = parse(resp.data);

    var seasons = body.querySelectorAll('.seasonOption');

    for (var season in seasons) {
      var data = season.attributes['data-season'];

      var eps = body.querySelectorAll('.episodeSelector').where((e) => e.attributes['data-season'] == data).first;

      log('$data - ${eps.children.length}');

      var epsData = [];

      for (var ep in eps.children) {
        var contentId = ep.attributes['data-contentid'];
        var name = ep.querySelector('.episodeNum')?.text;

        epsData.add({
          'data-contentid': contentId,
          'name': name,
        });
      }

      log(epsData.toString());

      itens.add({
        'season': data,
        'eps': epsData,
      });
    }

    loading = false;
    if (mounted) setState(() {});
    //
  }

  @override
  void initState() {
    getTempsAndEps();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
      ),
      body: Builder(
        builder: (context) {
          if (loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return ListView.builder(
            itemCount: itens.length,
            itemBuilder: (context, index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    itemBuilder: (context, iii) {
                      var ep = itens[index]['eps'][iii];
                      return ListTile(
                        onTap: () async {
                          //
                          try {
                            var options = await Dio().post(
                              'https://superflixapi.top/api',
                              data: FormData.fromMap(
                                {
                                  'action': 'getOptions',
                                  'contentid': ep['data-contentid'],
                                },
                              ),
                            );
                            log('passou Options');
                            var videoId = options.data['data']['options'].first['ID'];

                            var player = await Dio().post(
                              'https://superflixapi.top/api',
                              data: FormData.fromMap(
                                {
                                  'action': 'getPlayer',
                                  'video_id': videoId,
                                },
                              ),
                            );

                            var playerURL = player.data['data']['video_url'];
                            launchUrl(Uri.parse(playerURL));
                            log(playerURL);
                          } catch (e) {
                            //show snackbar
                            log(e.toString());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Este episodio ainda não está disponível!'),
                              ),
                            );
                          }
                        },
                        title: Text(ep['name']),
                        subtitle: Text('Temporada ${itens[index]['season']}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            )),
                      );
                    },
                    itemCount: itens[index]['eps'].length,
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}
