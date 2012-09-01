#env perl
use v5.014;
use OpenGL ':all';
use OpenGL::Shader;
use AnyEvent;
use Async::Interrupt;
use Time::HiRes; 
use Math::SegmentedEnvelope; # manage envelopes
use Net::LibLO; # recieve/send osc
use JSON::XS; # to unpack complex OSC data

my $osc = Net::LibLO->new( 25825 );
my $rate = 60; # default refresh rate for control values
my $timers = []; # timers bag
my @ctl = (0)x4; # simple control vector
my $oga = OpenGL::Array->new(16, GL_FLOAT); # 4x4 control matrix

$osc->add_method( '/ping', 'ifffs', sub { # osc responder
    state $env = Math::SegmentedEnvelope->new([[0,1,0], [0.05, 0.95], [2,2]])->static; # create static envelope evaluator
    state $step = []; # store number of steps for each controller
    my ($i, $dur, $amp, $freq, $arr) = splice(@_, 5, 5); # $i - controller index, $dur - duration of current event.. $arr - json packed data
    $timers->[$i] = { # create timers for controller
        start => AE::timer(0, 1/$rate, sub { # updater
            state $started = AE::now; # store start time
            $ctl[$i] = $env->((AE::now - $started) / $dur); # get control value from envelope
            $oga->assign(4*$i, $dur, $amp, $freq, $step->[$i]++); # assign control parameters
        }),
        stop => AE::timer($dur, 0, sub { $timers->[$i] = undef }) # stop updating after event duration
    }
} );

say 'press <q> to quit and <w> to toggle window/fullscreen mode';
gl_context(sub { # create gl context and pass drawing callback sub
    state $sh = do { # store shader
        my $sh = OpenGL::Shader->new('GLSL');
        $sh->LoadFiles('shader.frag','shader.vert');
        $sh;
    };
    state $started = AE::now; # store start time
    state $step = 0; # store frames counter
    $sh->Enable;
    $sh->SetVector('time', AE::now - $started, $step++);
    $sh->SetVector('ctl', @ctl);
    $sh->SetMatrix('ctm', $oga);
    glPushMatrix();
        glScaled(6,6,1);
        glTranslatef(-0.5,-0.5,-5);
        glRectf(0,0,1,1); # draw normalized rectangle
    glPopMatrix();
    # glPushMatrix();
    #     glScaled(($ctl[0]+1) x 2,1);
    #     glRotatef(-$ctl[1]*180+90,0,0,1);
    #     glTranslatef(-0.5,-0.5,-3);
    #     glRectf(0,0,1,1); # draw normalized rectangle
    # glPopMatrix();
    #my $test = glReadPixels_p(0,0,800,600,GL_RGB,GL_UNSIGNED_BYTE);
    $sh->Disable;
});

my $watch = AE::idle(sub {
    glutMainLoopEvent();
    glutPostRedisplay() if glutGetWindow();
    $osc->recv_noblock;
});

my $cond = AE::cv;
$cond->cb(sub { undef $watch });
$cond->recv;

sub gl_context { # opengl boiler plate
    my $draw_callback = shift;
    my $c = { # window config
        n => 'osc+opengl+glsl demo', # window name
        w => 800, # width
        h => 600, # height
        a => 60, # view angle
        np => 1, # near plane
        nf => 15, # far plane
    };
    
    glutInit();
    glutInitWindowSize($c->{w}, $c->{h});
    glutInitWindowPosition((glutGet(GLUT_SCREEN_WIDTH) - $c->{w}) / 2, (glutGet(GLUT_SCREEN_HEIGHT) - $c->{h}) / 2);
    glutInitDisplayMode(GLUT_RGBA|GLUT_DOUBLE|GLUT_ALPHA|GLUT_DEPTH);
    glutSetWindow(glutCreateWindow($c->{n}));
    glutSetCursor(GLUT_CURSOR_NONE);
    glShadeModel(GL_SMOOTH);
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_COLOR);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);

    glutReshapeFunc(sub {
        glViewport(0,0, glutGet(GLUT_WINDOW_WIDTH), glutGet(GLUT_WINDOW_HEIGHT));
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluPerspective($c->{a}, glutGet(GLUT_WINDOW_WIDTH)/glutGet(GLUT_WINDOW_HEIGHT), $c->{np}, $c->{nf});
        glMatrixMode(GL_MODELVIEW);
    });
    glutDisplayFunc(sub {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glClearColor(0, 0, 0, 0);
        glLoadIdentity();
        $draw_callback->();
        glutSwapBuffers();
    });
    glutKeyboardFunc(sub {
        my ($code) = @_;
        state $fullscreen = 0;
        given (chr($code)) {
            when ('q') { term() }
            when ('w') {
                $fullscreen = $fullscreen
                    ? do { 
                        glutReshapeWindow($c->{w}, $c->{h}); 
                        glutPositionWindow((glutGet(GLUT_SCREEN_WIDTH) - $c->{w}) / 2, (glutGet(GLUT_SCREEN_HEIGHT) - $c->{h}) / 2); 
                        0 
                    } 
                    : do { glutFullScreen(); 1 }
                }
        }
    });
}

sub term {
    glutKeyboardFunc(0);
    glutReshapeFunc(0);
    glutDestroyWindow(glutGetWindow());
    $cond->send;
}
