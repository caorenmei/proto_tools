package = "gen_model"
version = "dev-1"

source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}

description = {
   summary = "Generate protobuf descriptors with lua-protobuf; requires realpath in PATH at runtime.",
   homepage = "*** please enter a project homepage ***",
   license = "*** please specify a license ***"
}

dependencies = {
   "lua >= 5.4",
   "lua-protobuf == 0.5.3-1",
   "argparse",
   "busted",
   "lua-cjson",
   "luafilesystem",
}

build = {
   type = "builtin",
   modules = {}
}
