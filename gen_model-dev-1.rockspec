package = "gen_model"
version = "dev-1"

source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}

description = {
   homepage = "*** please enter a project homepage ***",
   license = "*** please specify a license ***"
}

dependencies = {
   "lua >= 5.4",
   "lua-protobuf",
   "argparse",
   "busted",
   "lua-cjson",
}

build = {
   type = "builtin",
   modules = {}
}
