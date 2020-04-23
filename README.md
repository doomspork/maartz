# Maartz

```shell
$ git clone git@github.com:doomspork/maartz.git
$ cd maartz
$ mix deps.get
$ mix compile
$ mix maartz.walker
```

#### The approach

Since we want to start on the homepage and crawl the entire domain looking for products we can conclude we'll need to do a few things. so that indicated to me that I would need to do a couple things:

1. Find all the links on a page
2. Filter those links for only those on this domain
3. To avoid the expense of crawling the same link twice we'd need to track links
4. Identify when a page was a product page to capture (or in this case output) the title and price
5. Repeat the above steps for each link we find.

#### Identifying links and product pages

We have a basic understand of Floki already so we won't go into that too deep. Identifying links on this domain was simple for this particular site because they rely on relative linking which we can look for easy enough. If they didn't we'd need to check for the domain in each URL and decide how to handle sub domains. Identifying a product page is also fairly simple since there are certain tags only present on those pages (eg `h1.pdp-card__title`, `.product-card-price__price--final`). If we find those we know we have the right page and we can do whatever needs to be done. Right now we use a simple `IO.puts/1` but this could be an API call to another service, a database call, or any number of actions.

#### Link storage

This is more of a cache than long term storage, we only need it to exist for the duration of our application's runtime. That makes [Erlang Term Storage](https://elixirschool.com/en/lessons/specifics/ets/) a great fit!  The previous link can give you a deeper dive into the ETS but the high level is that ETS is an in-memory key-value store, created and owned by processes in our application. 

We store values in ETS as a tuple where the first element is our key and the value as second. We strip our URL of fragments and query string[1] before generating a Base64 encoded hash, the use of Base64 is not required and only an example of encoding values in Elixir.

[1]: In hindsight blindly stripping all query strings may be causing us to miss some pages. We should probably take that out and observe how the system works.

Retrieving values out of ETS is super easy if you have the key, we just use `:ets.lookup/2` and give it our table and key. In the aforementioned link we can learn more about ETS to include querying for values using pattern matches.

#### These links were made for walking

Now that we know how to find our links and how to ensure we only crawl unique links, it's time we implement the actual crawling. As one can imagine there are thousands of pages to walk over in a large website such as the one we've picked. Walking these links and all the subsequent links sequentially would take _hours_ and possibly days. Thankfully for us Elixir (and OTP) make working asynchronously easy!

[Tasks](https://elixirschool.com/en/lessons/advanced/concurrency/) are one easy way to run a single asynchronously, we can decide to so in a way that allows us to retrieve the result or just fires off our task without concern for it's final value. Using a task can be as simple as surrounding a block of code in a `Task.async(fn -> ... end)` block! 

But what happens if our task fails? Elixir thought ahead and was kind of enough to provide us with a Supervisor made specifically for the task (pun totally intended): enter [TaskSupervisor](https://elixirschool.com/en/lessons/advanced/otp-supervisors/#task-supervisor). Once we setup our supervisor we need to update our task calls slightly `Task.Supervisor.async(Maartz.TaskSupervisor, fn -> ... end)` and now like magic our asynchronous work is supervised.