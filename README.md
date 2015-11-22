# Cappening / Conquest
Conquest is a location based game for [Happening](https://happening.im). Happening provides a cross-platform (Android, IOS, browser) app for group communication. The app supports plugins, which can interact with the people in the group in various ways ([current API documentation](https://github.com/happening/docs/wiki)). For an assignment part of the Bachelor Technische Informatica (Computer Science) at the University of Twente we created a plugin for Happening. This assignment was to do a 'real-life' project for a company from start to end. The group consists of Patrick van Looy, Vincent Smit, Sem Spenkelink, Lars Stegeman, Mathijs van de Zande and Thijs Wiefferink. Djoerd Hiemstra and Victor de Graaff supported the project from the side of the University of Twente. Emiel Mols, Frank van Viegen and Jelmer Feenstra supported the project from the side of Happening.

Now something about the game, first of all you need a group in Happening, if you have that the game can be found in the store with the name 'Conquest'. The game is played with 2 or more teams, these teams fight against eachother by taking over beacons. A beacon is a real-life location that is virtually marked on the map in the plugin. A beacon has a radius of 150 meters and when a team member is in range of the beacon the game will start capturing the beacon. For capturing beacons and keeping them for a long time teams get points, whoever has the most points at the end of the game wins.


Lets do a walkthrough of the game. First a couple of things need to be setup, the number of teams that you want to have (members of the Happening group will be divided among the teams) needs to be selected and the time that you want the game to last.

![Teams and time setup](https://cloud.githubusercontent.com/assets/6951068/11324551/317198a8-9135-11e5-9b24-bf4d689691c2.png)


Then on the next page the game area can be selected, you could for example select the city bounds, only a part of the city or a complete country. The grey pushpin indicates your own location, so that you know where you are now.

![Game area setup](https://cloud.githubusercontent.com/assets/6951068/11324552/36c830f0-9135-11e5-84ca-05a8d86451fd.png)

On the final setup page you can place beacons, it is recommended to place the beacons on locations that are visited by at least of couple of the happening members quite often. You can place as many beacons as you want, depending on the game area size, the time and number of players.

![Beacons setup](https://cloud.githubusercontent.com/assets/6951068/11324553/39bed980-9135-11e5-99cf-4751edc40df0.png)


Now the game is started and everyone can start capturing the beacons! Below you can see that team orange captured a beacon (the beacon changes to the color of the team that captured it). The game also indicates how far you are away from your current map view. In the top bar there are two buttons, the Events page and the Ranking page. These are described below.

![Main view](https://cloud.githubusercontent.com/assets/6951068/11324556/3f719908-9135-11e5-9192-235ce60f1cfd.png)


The Events page has a list of events that happened in the game, which includes beacon captured, ranking switches and the final winner.

![Events page](https://cloud.githubusercontent.com/assets/6951068/11324558/45491086-9135-11e5-8318-01ec7e6cf805.png)


The Ranking page shows all the teams, and how many points they have collected. It also shows how many points, captures and neutralizes each team member has.

![Ranking page](https://cloud.githubusercontent.com/assets/6951068/11324557/4247aab4-9135-11e5-9a52-6af78f7040db.png)


Capturing beacons takes 30 seconds from the point where you enter the area, the progress is shown in a capture bar at the top of the screen. If a beacon is owned by another team, then it first takes 30 seconds to neutralize before it can be captured.

![Capturing](https://cloud.githubusercontent.com/assets/6951068/11324581/a0bb0438-9135-11e5-9f8f-29d562cfa5c5.png)
![Captured](https://cloud.githubusercontent.com/assets/6951068/11324579/9a1264be-9135-11e5-8261-7efbf0f54beb.png)
