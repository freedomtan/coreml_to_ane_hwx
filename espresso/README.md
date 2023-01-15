* get input/output tensor names and shapes from espresso.{net,shape}

In modern macOS and iOS, most Core ML models are in *.espresso.{net,shape,weights}. Yes, there are some in mlmodelc format and 
some are .hwx only, but they are relative few. For example, on macOS Ventura, we can find a scene detection network model
related files described in Apple's "A Multi-Task Neural Architecture for On-Device Scene Analysis" article [1].

```
/System/Library/Frameworks/Vision.framework/Resources/SceneNet*
```

Checking a model's input/output tensor names and shapes could tell us somethings.
It's seem quite obvious that the layer/op names and the shapes of layers of espresso models are in .espresso.{net,shape} files.
The .espresso.{net,shape} files in iOS and macOS are in either json for lzfse [2] compressed json.

Reading .json (either compressed or not) should be trivial. However, it seems some models are not stored in a consistent
well-formated way, so we have to add some hacks.

Before running the script, install lzfse python binding, `pip install pyliblzfse`

Then we can do 
```bash
$ python  parse_net.py  /System/Library/Frameworks/Vision.framework/Resources/SceneNet_v5.10.0_vhh2692239_fe1.3_sc3.3_sa2.4_ae2.4_so2.4_od1.5_fp1.5.espresso.net 
```
and get
```
  input: image {'k': 3, 'w': 360, 'n': 1, '_rank': 4, 'h': 360}
  output:  inner/sceneprint {'k': 768, 'w': 1, 'n': 1, '_rank': 4, 'h': 1}
  output:  classification/labels {'k': 1374, 'w': 1, 'n': 1, '_rank': 4, 'h': 1}
  output:  aesthetics/scores {'k': 2, 'w': 1, 'n': 1, '_rank': 4, 'h': 1}
  output:  aesthetics/attributes {'k': 21, 'w': 1, 'n': 1, '_rank': 4, 'h': 1}
  output:  detection/scores {'k': 30, 'w': 90, 'n': 1, '_rank': 4, 'h': 90}
  output:  detection/coordinates {'k': 4, 'w': 90, 'n': 1, '_rank': 4, 'h': 90}
  output:  fingerprint/embedding {'k': 4, 'w': 6, 'n': 1, '_rank': 4, 'h': 6}
  output:  objectness/map {'k': 1, 'w': 68, 'n': 1, '_rank': 4, 'h': 68}
  output:  saliency/map {'k': 1, 'w': 68, 'n': 1, '_rank': 4, 'h': 68}

```

Surely, we can do
```
for m in /System/Library/Frameworks/Vision.framework/Resources/*.espresso.net;do python parse_net.py $m ;done
```
to dump all the `Vision.framework` models.

[1] https://machinelearning.apple.com/research/on-device-scene-analysis

[2] https://en.wikipedia.org/wiki/LZFSE
