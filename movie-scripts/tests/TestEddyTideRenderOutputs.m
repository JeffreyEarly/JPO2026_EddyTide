function tests = TestEddyTideRenderOutputs
% Check raster output and protect existing artifacts before loading model state.
tests = functiontests(localfunctions);
end

function setup(testCase)
folder = string(tempname);
mkdir(folder);
source = fullfile(folder,"times.nc");
nccreate(source,"/wave-vortex/t",Dimensions={"t",3},Format="netcdf4");
ncwrite(source,"/wave-vortex/t",[0;21600;43200]);
testCase.TestData.folder = folder;
testCase.TestData.source = source;
end

function teardown(testCase)
rmdir(testCase.TestData.folder,"s");
end

function testNonemptyFrameFolderIsPreserved(testCase)
folder = fullfile(testCase.TestData.folder,"frames");
mkdir(folder);
sentinel = fullfile(folder,"frame-000001.png");
imwrite(uint8(73*ones(2,2,3)),sentinel);
verifyError(testCase,@()MakeEddyTideCutawayMovie(inputFile=testCase.TestData.source,outputFormat="png",outputFolder=folder,cutMode="fixed"),"EddyTide:FrameFolderNotEmpty");
verifyEqual(testCase,imread(sentinel),uint8(73*ones(2,2,3)));
verifyFalse(testCase,isfile(fullfile(folder,"frames.mat")));
end

function testFrameDestinationMustBeADirectory(testCase)
verifyError(testCase,@()MakeEddyTideCutawayMovie(inputFile=testCase.TestData.source,outputFormat="png",outputFolder=testCase.TestData.source,cutMode="fixed"),"EddyTide:InvalidFrameFolder");
verifyError(testCase,@()MakeEddyTideCutawayMovie(inputFile=testCase.TestData.source,outputFormat="png",outputFolder="",cutMode="fixed"),"EddyTide:InvalidFrameFolder");
end

function testExistingMovieArtifactsArePreserved(testCase)
for extension = [".mp4",".partial.mp4",".mat"]
    output = fullfile(testCase.TestData.folder,"movie.mp4");
    existing = fullfile(testCase.TestData.folder,"movie" + extension);
    writelines("keep this existing artifact",existing);
    verifyError(testCase,@()MakeEddyTideCutawayMovie(inputFile=testCase.TestData.source,outputFile=output,cutMode="fixed"),"EddyTide:MovieExists");
    verifyEqual(testCase,strtrim(string(fileread(existing))),"keep this existing artifact");
    delete(existing);
end
end

function testVideoExtensionIsValidated(testCase)
verifyError(testCase,@()MakeEddyTideCutawayMovie(inputFile=testCase.TestData.source,outputFile=fullfile(testCase.TestData.folder,"movie.png"),cutMode="fixed"),"EddyTide:MovieExtension");
end

function testRasterDimensionsPrecisionAndBackground(testCase)
fig = figure(Visible="off",Color="white",Units="pixels",Position=[80 80 1600 900],WindowStyle="normal");
figureCleanup = onCleanup(@()close(fig));
ax = axes(fig,Position=[0.25 0.25 0.5 0.5]);
gradient = repmat(linspace(0,1,512),128,1,3);
image(ax,gradient);
axis(ax,"off");
for scale = [1 2]
    [rgb,raster] = renderEddyTideFigure(fig,scale);
    verifySize(testCase,rgb,[scale*1080 scale*1920 3]);
    verifyClass(testCase,rgb,"uint8");
    verifyEqual(testCase,raster.bitsPerChannel,8);
    verifyEqual(testCase,raster.sampleClass,"uint8");
    verifyEqual(testCase,raster.matlabVersion,string(version));
    verifyEqual(testCase,raster.matlabRelease,string(version("-release")));
    verifyEqual(testCase,rgb(1,1,:),uint8(255*ones(1,1,3)));
    verifyEqual(testCase,rgb(end,end,:),uint8(255*ones(1,1,3)));
    % The rendered gradient must retain variation across the interior.
    row = rgb(round(end/2),:,1);
    verifyGreaterThan(testCase,numel(unique(row)),200);
    output = fullfile(testCase.TestData.folder,"gradient-" + scale + ".png");
    imwrite(rgb,output,"png");
    info = imfinfo(output);
    verifyEqual(testCase,[info.Width info.Height],scale*[1920 1080]);
    verifyEqual(testCase,info.BitDepth,3*raster.bitsPerChannel);
    verifyEqual(testCase,imread(output),rgb);
end
end
