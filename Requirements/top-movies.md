# Epic: Top Movies (Do This First)

> **Start here.** This epic covers bug fixes and improvements to the existing Top Ranked Movies list — the screen the app ships with today (`[URBNFlicks/Views/MovieListViewController.swift](../URBNFlicks/Views/MovieListViewController.swift)` and `[URBNFlicks/Views/MovieTableViewCell.swift](../URBNFlicks/Views/MovieTableViewCell.swift)`). Getting this screen solid gives you the foundation (networking, models, navigation) that the rest of the backlog builds on.

This epic works with the existing UIKit Top Movies screen, so these fixes live in that UIKit code. All net-new screens in the other epics are SwiftUI.


| #   | Story                                                                                                                                                                                                                                                                                                                     | Done |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Our movie list cells are a mess — fix the layout issues. Display poster images in the correct aspect ratio; pin the title and rating near the top of the cell; pin the release year at the bottom; address any constraint warnings. Follow the UI guidelines in the redline: `[Comps/redline.png](../Comps/redline.png)`. | [x]  |
| 2   | There is laggy scrolling behavior on the main movie feed. Make the changes required to improve performance.                                                                                                                                                                                                               | [x]  |
| 3   | If the API or network fails, the user is never told. Add error handling on the main view controller to inform the user.                                                                                                                                                                                                   | [x]  |
| 4   | Movies are currently sorted only by Top Ranking. Add sorting options: alphabetical by title; by release year, newest first; by release year, oldest first. Indicate the current sorting method in the contextual menu.                                                                                                    | [ ]  |


