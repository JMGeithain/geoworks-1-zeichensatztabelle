#!/usr/bin/perl
use strict;
use warnings;
use lib (($ENV{SDK} || "../pcgeos-1-sdk-v2") . "/tools/lib");
use PCGEOS::Geos1::Format qw(from_bytes);
use PCGEOS::Geos1::Writer qw(build_geode);
use PCGEOS::Ensemble12::Objects qw(object_block text_moniker SAME_BLOCK);

my ($in, $out, $w, $h) = @ARGV;
die "usage: postbuild.pl input.geo output.geo width height\n" unless $h;
sub slurp { open my $f, '<:raw', $_[0] or die "$_[0]: $!"; local $/; <$f> }
sub set16 { my ($r,$at,$v)=@_; substr($$r,$at,2)=pack('v',$v) }
sub base {
    my ($ord,%o)=@_;
    pack('v14',0x3000,$ord,0,8,0,0,@{$o{sibling}//[0,0]},
      @{$o{child}//[0,0]},$o{moniker}//0,$o{accel}//0,$o{hints}//0,$o{states}//0xc000)
}
sub moniker { my ($text,$mn)=@_; pack('vvCC',1,0,0,$mn//0xff).$text."\0" }

my $g = from_bytes(slurp($in), $in);
my @res = map {{ data=>$_->{data}, flags=>$_->{flags},
    relocations=>[map {[$_->{info},$_->{extra},$_->{offset}]} @{$_->{relocations}}] }}
    @{$g->{resources}};
die "expected the 5 ensemble12 resources\n" unless @res == 5;

my $nm = ord(substr($res[1]{data},0x46,1));
die "process methods overlap the application data\n" if 0x52+6*$nm > 0xC0;
my $code = $res[2]{data};
my $vt = index($code,'G1VISCLS');
die "G1VISCLS table missing\n" if $vt < 0;
my $vn = unpack('v',substr($code,$vt+8,2));
my @vm = unpack("v$vn",substr($code,$vt+10,2*$vn));
my @vh = unpack("v$vn",substr($code,$vt+10+2*$vn,2*$vn));
my $vis_class = 0x100;
{
    my $dg = $res[1]{data};
    die "DGROUP must be 256 bytes\n" unless length($dg)==0x100;
    my $cls=pack('v9',0xa3,0xa3,4,$vn,0x56,0,0,0,0x0300).pack("v$vn",@vm);
    my @rel=([0x11,0,$vis_class],[0x12,0,$vis_class+2]);
    for my $i (0..$vn-1) {
        push @rel,[0x22,0,$vis_class+length($cls)+2];
        $cls.=pack('vv',$vh[$i],2);
    }
    $cls.="\0" x ((16-length($cls)%16)%16);
    $res[1]{data}=$dg.$cls;
    push @{$res[1]{relocations}},@rel;
    substr($res[1]{data},0x14,2)=pack('v',length($res[1]{data}));
}

my ($primary_h,$title_h,$view_h,$app_h)=(0x24,0x26,0x28,0x24);
my $primary=base(88,sibling=>[$app_h|1,0x1004],child=>[$view_h,SAME_BLOCK],moniker=>$title_h)."\0" x 5;
set16(\$primary,0x1c,0x22); set16(\$primary,0x1e,0x80);
my $mkview=sub {
    my $sib=shift;
    my $v=base(75,sibling=>$sib); $v.="\0" x (71-length($v));
    my %f=(0x20=>1,0x24=>1,0x2a=>15,0x2e=>0x8000,0x32=>$w,0x34=>$h,
      0x36=>$w,0x38=>$h,0x3a=>10,0x3c=>10,0x3e=>20,0x40=>15,0x44=>0x1000);
    set16(\$v,$_,$f{$_}) for keys %f;
    substr($v,0x46,1)=pack('C',1);
    return $v;
};
my $check=object_block(3,{
    $primary_h=>[$primary,3],
    $title_h=>[text_moniker($g->{long_name}),2],
    $view_h=>[$mkview->([$primary_h|1,SAME_BLOCK]),7]
},6);
die "interface block differs from the SDK output\n" unless $check eq $res[3]{data};

my ($filemenu,$filemenu_m,$filemenu_hints)=(0x2a,0x2c,0x2e);
my @file_items=(['Zeichentabelle',0x0c20],['Zeichen kopieren',0x0c21],
                ['Info',0x0c22],['Hilfe',0x0c23]);
my @file_chunks=map { [0x30+$_*4,0x32+$_*4] } 0..$#file_items;
my ($fontmenu,$fontmenu_m,$fontmenu_hints)=(0x40,0x42,0x44);
my @font_items=(['Berkeley',0x0c10],['Roman',0x0c11],['Sans',0x0c12],['Mono',0x0c13],
                ['Weitere Schriften...',0x0c16]);
my @font_chunks=map { [0x46+$_*4,0x48+$_*4] } 0..$#font_items;
my $vh=0x66;
my ($tb,$tb_hints)=(0x74,0x72);
my $view=$mkview->([$filemenu,SAME_BLOCK]);
set16(\$view,0x18,$vh);
set16(\$view,0x2e,0xd010);
set16(\$view,0x42,0x22);
set16(\$view,0x44,0x1005);
my %chunks=(
    $primary_h=>[$primary,3],
    $title_h=>[text_moniker($g->{long_name}),2],
    $view_h=>[$view,7],
    $filemenu=>[base(80,sibling=>[$fontmenu,SAME_BLOCK],child=>[$file_chunks[0][0],SAME_BLOCK],moniker=>$filemenu_m,hints=>$filemenu_hints).pack('C',2),3],
    $filemenu_m=>[moniker('Datei',0),2],
    $filemenu_hints=>[pack('vv',0x4005,4),2],
    $fontmenu=>[base(80,sibling=>[$tb,SAME_BLOCK],child=>[$font_chunks[0][0],SAME_BLOCK],moniker=>$fontmenu_m,hints=>$fontmenu_hints).pack('C',2),3],
    $fontmenu_m=>[moniker('Schrift',5),2],
    $fontmenu_hints=>[pack('vv',0x4005,4),2],
    $vh=>[pack('v4',0x4015,4,0x4014,4),2]
);
# A real GEOS toolbar, with native GenTrigger buttons. GeoZeit uses the same
# GenInteraction/GenTrigger pattern rather than drawing button-looking text.
my @tools=(['Weitere Schriften...',0x0c16],['Zeichen kopieren',0x0c21]);
$chunks{$tb}=[base(80,sibling=>[$primary_h|1,SAME_BLOCK],child=>[0x68,SAME_BLOCK],hints=>$tb_hints).pack('C',2),3];
$chunks{$tb_hints}=[pack('vv',0x402b,4),2];
for my $i (0..$#tools) {
    my ($label,$msg)=@{$tools[$i]};
    my $th=0x68+4*$i; my $mh=$th+2;
    my $sibling=$i<$#tools ? [$th+4,SAME_BLOCK] : [$tb|1,SAME_BLOCK];
    $chunks{$th}=[base(68,sibling=>$sibling,moniker=>$mh,states=>0xc004).pack('vvv',0x22,0x1005,$msg),7];
    $chunks{$mh}=[moniker($label,0xff),2];
}
for my $i (0..$#file_items) {
    my ($label,$msg)=@{$file_items[$i]};
    my ($trigger,$mh)=@{$file_chunks[$i]};
    my $sibling=$i<$#file_items ? [$file_chunks[$i+1][0],SAME_BLOCK] : [$filemenu|1,SAME_BLOCK];
    $chunks{$trigger}=[base(68,sibling=>$sibling,moniker=>$mh,states=>0xc004).pack('vvv',0x22,0x1005,$msg),7];
    $chunks{$mh}=[moniker($label,0),2];
}
for my $i (0..$#font_items) {
    my ($label,$msg)=@{$font_items[$i]};
    my ($trigger,$mh)=@{$font_chunks[$i]};
    my $sibling=$i<$#font_items ? [$font_chunks[$i+1][0],SAME_BLOCK] : [$fontmenu|1,SAME_BLOCK];
    # Send the action to the custom VisContent object, which owns the table
    # and handles these font-selection messages directly.
    $chunks{$trigger}=[base(68,sibling=>$sibling,moniker=>$mh,states=>0xc004).pack('vvv',0x22,0x1005,$msg),7];
    $chunks{$mh}=[moniker($label,0),2];
}
$chunks{$view_h}[0]=$view;
my $chunk_count=($tb+2-0x20)/2;
$chunk_count++ if $chunk_count%2;
$res[3]{data}=object_block(3,\%chunks,$chunk_count);

my $inst=pack('H*','01600000060000000000f3018f01d878f000000000000000000000000000000000020000000000000046000d1000000000000000000000000000aa00a900000000000000ac00ab00000000000000b200b100000000000000b400b300');
my $at=index($inst,pack('vv',0x46,0x100d));
die "view link not found in the Vis instance\n" if $at<0;
substr($inst,$at,4)=pack('vv',0x28,0x1003);
substr($inst,10,4)=pack('vv',3999,2999);
my $vis=object_block(5,{0x22=>[$inst,3]},2);
my $fp=unpack('v',substr($vis,0x20,2));
substr($vis,$fp+1,1)=pack('C',3);
push @res,{data=>$vis,flags=>0x41a,relocations=>[[0x23,0,0]]};

my $new=build_geode(
    name=>$g->{name}, extension=>$g->{extension}, long_name=>$g->{long_name},
    token=>pack('H*',substr($g->{token_hex},0,8)), attributes=>$g->{attributes},
    file_type=>1, release=>$g->{release}, protocol=>$g->{protocol},
    kernel_protocol=>$g->{kernel_protocol}, udata_size=>4096, resources=>\@res,
    imports=>[map {{name=>$_->{name},attributes=>$_->{attributes},protocol=>$_->{protocol}}} @{$g->{imports}}],
    process_class=>[1,0x40], application_object=>[4,0x24], exports=>[[1,$vis_class]]
);
open my $f,'>:raw',$out or die "$out: $!";
print $f $new->{raw}; close $f;
printf "%s: %d bytes, %d resources, Vis input class installed\n",$out,length($new->{raw}),scalar @res;

