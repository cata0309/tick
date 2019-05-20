"""fips verb to build the samples webpage"""

import os
import yaml 
import shutil
import subprocess
import glob
from string import Template

from mod import log, util, project, emscripten, android

# sample attributes
samples = [
    [ 'clear', 'clear-sapp.c' ],
    [ 'triangle', 'triangle-sapp.c' ],
    [ 'quad', 'quad-sapp.c' ],
    [ 'bufferoffsets', 'bufferoffsets-sapp.c'],
    [ 'cube', 'cube-sapp.c' ],
    [ 'noninterleaved', 'noninterleaved-sapp.c'],
    [ 'texcube', 'texcube-sapp.c' ],
    [ 'offscreen', 'offscreen-sapp.c' ],
    [ 'instancing', 'instancing-sapp.c' ],
    [ 'mrt', 'mrt-sapp.c' ],
    [ 'arraytex', 'arraytex-sapp.c' ],
    [ 'dyntex', 'dyntex-sapp.c'],
    [ 'mipmap', 'mipmap-sapp.c'],
    [ 'blend', 'blend-sapp.c' ],
    [ 'imgui', 'imgui-sapp.cc' ],
    [ 'imgui-highdpi', 'imgui-highdpi-sapp.cc' ],
    [ 'sgl-microui', 'sgl-microui-sapp.c'],
    [ 'saudio', 'saudio-sapp.c'],
    [ 'modplay', 'modplay-sapp.c' ],
    [ 'noentry', 'noentry-sapp.c' ],
    [ 'sgl', 'sgl-sapp.c' ],
    [ 'sgl-lines', 'sgl-lines-sapp.c' ]
]

# webpage template arguments
GitHubSamplesURL = 'https://github.com/floooh/sokol-samples/tree/master/sapp/'

# build configuration
BuildConfig = 'sapp-webgl2-wasm-ninja-release'

#-------------------------------------------------------------------------------
def deploy_webpage(fips_dir, proj_dir, webpage_dir) :
    """builds the final webpage under under fips-deploy/sokol-webpage"""
    ws_dir = util.get_workspace_dir(fips_dir)
    wasm_deploy_dir = '{}/fips-deploy/sokol-samples/{}'.format(ws_dir, BuildConfig)

    # create directories
    for platform in ['wasm'] :
        platform_dir = '{}/{}'.format(webpage_dir, platform)
        if not os.path.isdir(platform_dir) :
            os.makedirs(platform_dir)

    # build the thumbnail gallery
    content = ''
    for sample in samples :
        name = sample[0]
        log.info('> adding thumbnail for {}'.format(name))
        url = "wasm/{}-sapp.html".format(name)
        ui_url = "wasm/{}-sapp-ui.html".format(name)
        img_name = name + '.jpg'
        img_path = proj_dir + '/webpage/' + img_name
        if not os.path.exists(img_path):
            img_name = 'dummy.jpg'
            img_path = proj_dir + 'webpage/dummy.jpg'
        content += '<div class="thumb">\n'
        content += '  <div class="thumb-title">{}</div>\n'.format(name)
        if os.path.exists(wasm_deploy_dir + '/' + name + '-sapp-ui.js'):
            content += '<a class="img-btn-link" href="{}"><div class="img-btn">UI</div></a>'.format(ui_url)
        content += '  <div class="img-frame"><a href="{}"><img class="image" src="{}"></img></a></div>\n'.format(url,img_name)
        content += '</div>\n'

    # populate the html template, and write to the build directory
    with open(proj_dir + '/webpage/index.html', 'r') as f :
        templ = Template(f.read())
    html = templ.safe_substitute(samples=content)
    with open(webpage_dir + '/index.html', 'w') as f :
        f.write(html)

    # copy other required files
    for name in ['dummy.jpg', 'favicon.png'] :
        log.info('> copy file: {}'.format(name))
        shutil.copy(proj_dir + '/webpage/' + name, webpage_dir + '/' + name)

    # generate WebAssembly HTML pages
    if emscripten.check_exists(fips_dir) :
        for sample in samples :
            name = sample[0]
            source = sample[1]
            log.info('> generate wasm HTML page: {}'.format(name))
            for postfix in ['sapp', 'sapp-ui']:
                for ext in ['wasm', 'js'] :
                    src_path = '{}/{}-{}.{}'.format(wasm_deploy_dir, name, postfix, ext)
                    if os.path.isfile(src_path) :
                        shutil.copy(src_path, '{}/wasm/'.format(webpage_dir))
                    with open(proj_dir + '/webpage/wasm.html', 'r') as f :
                        templ = Template(f.read())
                    src_url = GitHubSamplesURL + source
                    html = templ.safe_substitute(name=name, prog=name+'-'+postfix, source=src_url)
                    with open('{}/wasm/{}-{}.html'.format(webpage_dir, name, postfix), 'w') as f :
                        f.write(html)

    # copy the screenshots
    for sample in samples :
        img_name = sample[0] + '.jpg'
        img_path = proj_dir + '/webpage/' + img_name
        if os.path.exists(img_path):
            log.info('> copy screenshot: {}'.format(img_name))
            shutil.copy(img_path, webpage_dir + '/' + img_name)

#-------------------------------------------------------------------------------
def build_deploy_webpage(fips_dir, proj_dir, rebuild) :
    # if webpage dir exists, clear it first
    ws_dir = util.get_workspace_dir(fips_dir)
    webpage_dir = '{}/fips-deploy/sokol-webpage'.format(ws_dir)
    if rebuild :
        if os.path.isdir(webpage_dir) :
            shutil.rmtree(webpage_dir)
    if not os.path.isdir(webpage_dir) :
        os.makedirs(webpage_dir)

    # compile samples
    if emscripten.check_exists(fips_dir) :
        project.gen(fips_dir, proj_dir, BuildConfig)
        project.build(fips_dir, proj_dir, BuildConfig)
    
    # deploy the webpage
    deploy_webpage(fips_dir, proj_dir, webpage_dir)

    log.colored(log.GREEN, 'Generated Samples web page under {}.'.format(webpage_dir))

#-------------------------------------------------------------------------------
def serve_webpage(fips_dir, proj_dir) :
    ws_dir = util.get_workspace_dir(fips_dir)
    webpage_dir = '{}/fips-deploy/sokol-webpage'.format(ws_dir)
    p = util.get_host_platform()
    if p == 'osx' :
        try :
            subprocess.call(
                'open http://localhost:8000 ; python {}/mod/httpserver.py'.format(fips_dir),
                cwd = webpage_dir, shell=True)
        except KeyboardInterrupt :
            pass
    elif p == 'win':
        try:
            subprocess.call(
                'cmd /c start http://localhost:8000 && python {}/mod/httpserver.py'.format(fips_dir),
                cwd = webpage_dir, shell=True)
        except KeyboardInterrupt:
            pass
    elif p == 'linux':
        try:
            subprocess.call(
                'xdg-open http://localhost:8000; python {}/mod/httpserver.py'.format(fips_dir),
                cwd = webpage_dir, shell=True)
        except KeyboardInterrupt:
            pass

#-------------------------------------------------------------------------------
def run(fips_dir, proj_dir, args) :
    if len(args) > 0 :
        if args[0] == 'build' :
            build_deploy_webpage(fips_dir, proj_dir, False)
        elif args[0] == 'rebuild' :
            build_deploy_webpage(fips_dir, proj_dir, True)
        elif args[0] == 'serve' :
            serve_webpage(fips_dir, proj_dir)
        else :
            log.error("Invalid param '{}', expected 'build' or 'serve'".format(args[0]))
    else :
        log.error("Param 'build' or 'serve' expected")

#-------------------------------------------------------------------------------
def help() :
    log.info(log.YELLOW +
             'fips webpage build\n' +
             'fips webpage rebuild\n' +
             'fips webpage serve\n' +
             log.DEF +
             '    build sokol samples webpage')

