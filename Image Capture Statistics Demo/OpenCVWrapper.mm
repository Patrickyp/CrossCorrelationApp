//  OpenCVWrapper.m
//  TestOpenCVSwift
//
//  Created by Patrick Pan on 11/14/16.
//  Copyright © 2016 OpenCV Moments. All rights reserved.
//
//  Tutorial used to create ObjectiveC bridging header: https://www.youtube.com/watch?v=ywUBHqxwM5Q
//  This file implements 2 functions that can be called from ViewController.swift.


#import "OpenCVWrapper.h"
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>

#import <opencv2/imgcodecs.hpp>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgproc/imgproc.hpp>

#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <algorithm>
#include <math.h>
@implementation OpenCVWrapper

//using namespace std;
//using namespace cv;



// ****************************************
std::vector<std::vector<int>> resultXCoordinates;
std::vector<std::vector<int>> resultYCoordinates;

std::vector<std::vector<int>> dXArray;
std::vector<std::vector<int>> dYArray;

double xCorrCooefficientCutoff = 0.5;
int badXCorrValue = -999;

/*
 This function takes an array of even number of UIImages, does cross-correlation to calculate dx and dy for each template location on each pair and save the resulted arrowed images to library.  All dx and dy with cross correlation cooefficient above xCorrCooefficientCutoff are averaged into a arrowed image representing the average that saved to library and returned as UIImage to caller.
*/
+ (UIImage *) findTemplatev2:(NSArray*)imageArray distanceFromTarget:(double)distance calculatedVelocity:(double *)velocity;
{
    cv::Mat stockImage;
    UIImageToMat(imageArray[0], stockImage);
    int tempSize = 150;
    
    int Image_YSize = stockImage.rows;
    int Image_XSize = stockImage.cols;
    int NumXGrid = floor(Image_XSize/tempSize)-3; // -3 to skip outermost points, otherwise would be -1
    int NumYGrid = floor(Image_YSize/tempSize)-3;
    int SPX [NumXGrid];
    int SPY [NumYGrid];
    
    
    int count = 0;
    // Save x coordinate of template center to SPX.  Starting at 2 to skip outer most point.  Using NumXGrid+2 to compensate for that.
    for (int x = 2; x < NumXGrid+2; x++){
        SPX[count] = x * tempSize; //SPX contains all x coordinates of template center.
        std::cout << "X = " << SPX[count] << std::endl;
        count++;
    }
    std::cout << "XCount = " << count << std::endl;
    
    count = 0;
    // Save y coordinate of template center to SPY.
    for (int y = 2; y < 2 + NumYGrid; y++){
        SPY[count] = y * tempSize;
        std::cout << "Y = " << SPY[count] << std::endl;
        count++;
    }
    std::cout << "YCount = " << count << std::endl;
    
    int SearchPointSize = (NumXGrid) * (NumYGrid);
    int SearchPointX[SearchPointSize];
    int SearchPointY[SearchPointSize];
    
    count = 0;
    for (int x = 0; x < NumXGrid; x++){
        for (int y = 0; y < NumYGrid; y++){
            SearchPointX[count] = SPX[x];
            SearchPointY[count] = SPY[y];
            count++;
        }
    }
    
    // Loop through all saved images and do crosscorrelation on each pair of images.  ImageArray is an NSArray of ALL the images.  We want to XCorr pairs until all of them are processed then get the average dx and dy
    for (int index = 0; index < ([imageArray count]/2); index++) {
        //std::cout << "index:" << index << std::endl;
        
        cv::Mat image1;
        cv::Mat image2;
        
        int doubleIndex = index * 2;
        UIImageToMat(imageArray[doubleIndex], image1);
        UIImageToMat(imageArray[doubleIndex+1], image2);
        
        //std::cout << "Image1XSize:" << Image_XSize << " Image1YSize:" << Image_YSize << " NumXGrid:" << NumXGrid << " NumYGrid:" << NumYGrid << std::endl;
        //std::cout << "Image2XSize:" << image2.cols << " Image2YSize:" << image2.rows << std::endl;
        
        // Do cross correlation on the 2 images.  Result template center and dx/dy are saved in global vector.
        Cross_Corr_Function_Ver2(image1, image2, SearchPointX, SearchPointY, tempSize, .5, SearchPointSize);
        
        // Graph arrows using data from global vector.
        for (int i = 0; i < resultXCoordinates[0].size(); i++) {
            int fontFace = cv::FONT_HERSHEY_SCRIPT_SIMPLEX;
            cv::Point originalPt = cv::Point(SearchPointX[i], SearchPointY[i]);
            cv::Point matchPt = cv::Point(resultXCoordinates[index][i], resultYCoordinates[index][i]);
            cv::putText(image1,"*",matchPt, fontFace, .5, cv::Scalar(0,0,255), 1,8);
            cv::arrowedLine(image1,originalPt,matchPt,cv::Scalar(255,0,0,255),2,CV_AA,0,0.2);
        }
        
        // Rotating image.
        //cv::Mat image1_rotate;
        cv::transpose(image1, image1);
        cv::flip(image1, image1, 1);
        
        
        UIImageWriteToSavedPhotosAlbum(MatToUIImage(image1), nil, nil, nil);
    }
    
    
    // Vector to store average dx and dy.
    std::vector<double> dXMedian;
    std::vector<double> dYMedian;
    
    // Calculate average dx and dy values stored in global vectors.  Looping through the inner vector first and the outer vector second to averaging the dx and dy for all first template match result (dxArray[0-dxArray.size()][0]), all second template match result (dxArray[0-dxArray.size()][1]) and so on.
    // dXArray and dYArray size should be the same.
    for (int i = 0; i < dXArray[0].size(); i++) {
        double dxSum = 0;
        double dySum = 0;
        int goodDXCount = 0;
        int goodDYCount = 0;
        
        for (int j = 0; j < dXArray.size(); j++) {
            int dx = dXArray[j][i];
            int dy = dYArray[j][i];
            // 0 means below xcorr threshold so ignore, otherwise add to average, if dx is 0 then dy should also be 0 so redundant for now.
            if ((dx != badXCorrValue) && (dy != badXCorrValue) ) {
                goodDXCount++;
                goodDYCount++;
                dxSum += dXArray[j][i];
                dySum += dYArray[j][i];
            }
        }
        
        // If at least 1 good dx and dy calculate average and save otherwise save 0 to indicate all dx and dy for this template location is bad.
        if ((goodDXCount != 0) && (goodDYCount != 0) ){
            double averageDX = dxSum / goodDXCount;
            goodDXCount = 0;
            dXMedian.push_back(averageDX);
            
            double averageDY = dySum / goodDYCount;
            goodDYCount = 0;
            dYMedian.push_back(averageDY);
        }
        else {
            dXMedian.push_back(badXCorrValue);
            dYMedian.push_back(badXCorrValue);
        }
        //std::cout << "dXMean = " << averageDX << std::endl;
    }

    // Graph average dx and dy arrows to first image.
    cv::Mat averageImage;
    UIImageToMat(imageArray[0], averageImage);
    
    for (int i = 0; i < dYMedian.size(); i++) {
        if(dXMedian[i] != badXCorrValue){
            int fontFace = cv::FONT_HERSHEY_SCRIPT_SIMPLEX;
            cv::Point originalPt = cv::Point(SearchPointX[i], SearchPointY[i]);
            cv::Point matchPt = cv::Point(SearchPointX[i]+dXMedian[i], SearchPointY[i]+dYMedian[i]);
            //cv::putText(image1Clone,"*",matchPt, fontFace, .5, cv::Scalar(0,0,255), 1,8);
            cv::arrowedLine(averageImage,originalPt,matchPt,cv::Scalar(255,0,0,255),3,CV_AA,0,0.2);
        }
        else {
            std::cout << "dx#" << i << " is 0! "<< std::endl;
        }
    }
    
    cv::transpose(averageImage, averageImage);
    cv::flip(averageImage, averageImage, 1);
    
    // Save final average dx and dy arrowed image to library.
    UIImageWriteToSavedPhotosAlbum(MatToUIImage(averageImage), nil, nil, nil);
    
    // Clear global vectors, we are done with xcorr all images.
    dXArray.clear();
    dYArray.clear();
    
    resultXCoordinates.clear();
    resultYCoordinates.clear();
    
    // Return final average dx and dy arrowed image.
    return MatToUIImage(averageImage);
}



int Cross_Corr_Function_Ver2(cv::Mat image1, cv::Mat image2, int* Img1XCenterForTemplate, int* Img1YCenterForTemplate, int TempSize, double CorrThreshold, int SearchPointSize) {
    
    int TempHeight = TempSize;
    int TempWidth = TempSize;
    int SearchWidth = 2 * TempWidth;
    int SearchHeight = 2 * TempHeight;
    
    // Store X and Y value of points obtained from XCorrelation.
    std::vector<int> resultXCoordinatesThisRun;
    std::vector<int> resultYCoordinatesThisRun;
    
    // Store dx and dy value obtained from given point and calculated point
    std::vector<int> dXArrayThisRun;
    std::vector<int> dYArrayThisRun;
    
    for (int i = 0; i < SearchPointSize; i++) {
        // Calculate the top-left corner of the template.
        int Img1XMinForTemplate = Img1XCenterForTemplate[i] - TempWidth / 2;
        int Img1YMinForTemplate = Img1YCenterForTemplate[i] - TempHeight / 2;
        
        // Calculate the top-left corner of the search region.
        int Img1XMinForSearchRegion = Img1XCenterForTemplate[i] - SearchWidth / 2;
        int Img1YMinForSearchRegion = Img1YCenterForTemplate[i] - SearchWidth / 2;
        //std::cout << "Img1XMinForTemplate:" << Img1XMinForTemplate << " Img1YMinForTemplate:" << Img1YMinForTemplate << " TempWidth:" << TempWidth << " TempHeight:" << TempHeight << std::endl;
        cv::Rect TempRect(Img1XMinForTemplate, Img1YMinForTemplate, TempWidth, TempHeight);
        cv::Mat Template = image1(TempRect);//.clone()
        //Template = 1.0f * Template - 20;
        
        cv::Rect SearchRect(Img1XMinForSearchRegion, Img1YMinForSearchRegion, SearchWidth, SearchHeight);
        cv::Mat SearchAreaImage = image2(SearchRect);
        //SearchAreaImage = 1.0f * SearchAreaImage - 20;
        cv::Mat SearchAreaImage2 = image1(SearchRect);
        //SearchAreaImage2 = 1.0f * SearchAreaImage2 - 20;
        
        
        /// Create the result matrix
        cv::Mat result;
        int result_cols = SearchAreaImage.cols - Template.cols + 1;
        int result_rows = SearchAreaImage.rows - Template.rows + 1;
        result.create(result_rows, result_cols, CV_32FC1 );
        
        /// Do the Matching and Normalize
        matchTemplate(SearchAreaImage, Template, result, 5);
        
        double minVal, maxVal;
        cv::Point minLoc, maxLoc, matchLoc;
        cv::minMaxLoc(result, &minVal, &maxVal, &minLoc, &maxLoc, cv::Mat());
        //std::cout << "Max ValueB4Norm: " << maxVal << "Min Value: " << minVal << std::endl;
        normalize(result, result, 0, 5, cv::NORM_MINMAX, -1, cv::Mat() );
        if (maxVal < xCorrCooefficientCutoff){
            //Template = 1.5f * Template - 50; //darken template
        }
        double garbage;
        // get the max and min location from the match mat
        cv::minMaxLoc(result, &garbage, &garbage, &minLoc, &maxLoc, cv::Mat());
        matchLoc = maxLoc;
        //std::cout << "Max Value: " << maxVal << std::endl;
        
        // Get the center x and y location of the result template in respect to SearchAreaImage
        int ResultXSearchAreaImage = matchLoc.x + TempWidth/2;
        int ResultYSearchAreaImage = matchLoc.y + TempWidth/2;
        
        // Convert coordinates above to x and y location in respect to entire image.
        int ResultXImage2 = ResultXSearchAreaImage + Img1XMinForSearchRegion;
        int ResultYImage2 = ResultYSearchAreaImage + Img1YMinForSearchRegion;
        
        // Save coordinate to local vector.
        resultXCoordinatesThisRun.push_back(ResultXImage2);
        resultYCoordinatesThisRun.push_back(ResultYImage2);
        
        int dx, dy;
        // If match quality above threshold save dx and dy otherwise save 0.
        if (maxVal > xCorrCooefficientCutoff) {
            dx = ResultXImage2 - Img1XCenterForTemplate[i];
            dy = ResultYImage2 - Img1YCenterForTemplate[i];
        }
        else {
            Template = 1.5f * Template - 50; //darken template
            dx = badXCorrValue;
            dy = badXCorrValue;
        }
        dXArrayThisRun.push_back(dx);
        dYArrayThisRun.push_back(dy);
    }
    
    // Push local vector to global 2d vector.  Global vector stores results for all image pairs.
    resultXCoordinates.push_back(resultXCoordinatesThisRun);
    resultYCoordinates.push_back(resultYCoordinatesThisRun);
    
    dXArray.push_back(dXArrayThisRun);
    dYArray.push_back(dYArrayThisRun);
    
    return 5;
}




std::vector<int>* findAverageDelta(std::vector<int>* result, std::vector<std::vector<int>>* xValues, std::vector<std::vector<int>>* yValues) {
    return result;
}
































/************************************************** OLD ***************************************/

//Function to do template matching.  Takes in 2 UIImage, convert them to Mat image, does the template matching, and return the result image back as UIImage.  This is an Objective C function with C++ code in it.  Make sure to update header file if changing this function.
+(UIImage *) findTemplate:(UIImage *)img1 templateImage:(UIImage *)img2 distanceFromTarget:(double)rDistance calculatedVelocity:(double *)velocity
{
    printf("Distance = %f", rDistance);
    int XPos1[100][100], YPos1[100][100];
    int XPos2[100][100], YPos2[100][100];
    
    int img1XCenterForTemplate;
    int img1YCenterForTemplate;
    int img1XMinForTemplate;
    int img1YMinForTemplate;
    
    cv::Mat c, initialImage1, initialImage2, templ;
    
    // Create Mat image variables and set them to the converted UIImages
    cv::Mat C1, C1_NO_ROTATE;
    UIImageToMat(img1, C1_NO_ROTATE);
    
    // Rotate image1 90 degrees CW
    cv::transpose(C1_NO_ROTATE, C1);
    cv::flip(C1, C1, 1);

    
    // Get length and width
    int cloud1_xsize = C1.cols;
    int cloud1_ysize = C1.rows;
    
    //std::cout << "Width : " << cloud1_xsize << std::endl;
    //std::cout << "Height: " << cloud1_ysize << std::endl;
    
    cv::Mat C2,C2_NO_ROTATE;
    UIImageToMat(img2, C2_NO_ROTATE);
    
    // Rotate image2 90 degrees CW
    cv::transpose(C2_NO_ROTATE, C2);
    cv::flip(C2, C2, 1);
    
    cv::Mat result;
    
    //rotate both images
    
    int minSize = std::min(cloud1_xsize, cloud1_ysize);
    int N = 6;
    int tempWidth = floor(minSize/N);
    int tempHeight = tempWidth; //square template
    
    int xDirectionBoxCount = floor(cloud1_xsize/tempWidth);
    int yDirectionBoxCount = floor(cloud1_ysize/tempHeight);
    
    //std::cout << "xDirectionBoxCount" << xDirectionBoxCount << "yDirectionBoxCount" << yDirectionBoxCount << "tempwidth" << tempWidth << "tempheight" << tempHeight << std::endl;
    
    for (int i = 2; i <= xDirectionBoxCount - 1; i++){
        for (int j = 2; j <= yDirectionBoxCount - 1; j++){
            
            img1XMinForTemplate = (i-1)*tempWidth + 1;
            img1YMinForTemplate = (j-1)*tempHeight + 1;
            
            img1XCenterForTemplate = img1XMinForTemplate + (tempWidth/2);
            img1YCenterForTemplate = img1YMinForTemplate + (tempHeight/2);
            
            cv::Rect rect(img1XMinForTemplate, img1YMinForTemplate, tempWidth, tempHeight);
            templ = C1(rect).clone();
            templ = 1.0f * templ - 20;
            
            int c_cols = C2.cols - templ.cols + 1;
            int c_rows = C2.rows - templ.rows + 1;
            c.create(c_rows, c_cols, CV_32FC1);
            
            cv::matchTemplate(C2, templ, c, 5);
            normalize(c, c, 0, 1, cv::NORM_MINMAX, -1, cv::Mat() );
            
            
            double minVal, maxVal;
            cv::Point minLoc, maxLoc, matchLoc;
            
            // get the max and min location from the match mat
            cv::minMaxLoc( c, &minVal, &maxVal, &minLoc, &maxLoc, cv::Mat() );
            matchLoc = maxLoc;
            
            int img2XCenter = matchLoc.x + tempWidth/2;
            int img2YCenter = matchLoc.y + tempWidth/2;
            
            XPos1[i][j] = img1XCenterForTemplate;
            YPos1[i][j] = img1YCenterForTemplate;
            XPos2[i][j] = img2XCenter;
            YPos2[i][j] = img2YCenter;
            
        }
    }
    
    double velocityTotal = 0;
    double velocityCount = 0;
    
    // Create a loop to graph '*' and arrows looping through the Xpos Ypos arrays
    int fontFace = cv::FONT_HERSHEY_SCRIPT_SIMPLEX;
    for (int i = 2; i <= xDirectionBoxCount-1; i++){
        for (int j = 2; j <= yDirectionBoxCount-1; j++){
            cv::Point pt1 = cv::Point(XPos1[i][j], YPos1[i][j]);
            cv::Point pt2 = cv::Point(XPos2[i][j], YPos2[i][j]);
            cv::Point Point1 = cv::Point(XPos1[i][j]-5, YPos1[i][j]+5);
            cv::Point Point2 = cv::Point(XPos2[i][j]-5, YPos2[i][j]+5);
            
            printf("Distance (r) = %f\n", rDistance);
            double distanceTwoPoint = calcDistanceTwoPoints(pt1, pt2);
            printf("Pixel Distance = %f\n", distanceTwoPoint);
            double distanceDegrees = pixelDistanceToDegree(distanceTwoPoint);
            printf("Degree Distance = %f\n", distanceDegrees);
            double distanceImages = calcDistanceBetweenTwoImage(distanceDegrees, rDistance);
            printf("ds = %f\n", distanceImages);
            double velocity = distanceImages / 1;
            printf("velocity = %f meter/second\n", velocity);
            velocityTotal += velocity;
            velocityCount++;
            
            //-5 and +5 because the symbol's bottom left corner corresponds to the point
            //and not the center
            cv::putText(C1,"*",Point1, fontFace, .5, cv::Scalar(0,0,255), 1,8);
            cv::putText(C1,"*",Point2, fontFace, .5, cv::Scalar(0,255,0), 1,8);
            
            //draw arrows from Point1 to Point2
            cv::arrowedLine(C1,pt1,pt2,cv::Scalar(255,0,0,255),3,CV_AA,0,0.2);
            
        }
    }
    
    //printf("Total velocity = %f\n", velocityTotal);
    double velocityAverage = velocityTotal / velocityCount;
    //printf("Average velocity = %f\n", velocityAverage);
    
    *velocity = velocityAverage;
    //std::cout << "function call done!" << std::endl;
    return MatToUIImage(C1);
}

// Calculate the pixel distance between 2 points
double calcDistanceTwoPoints(cv::Point pt1, cv::Point pt2){
    double distance;
    distance = sqrt((pt2.x - pt1.x) * (pt2.x - pt1.x) + (pt2.y - pt1.y) * (pt2.y - pt1.y));
    return distance;
}

// Convert change in distance from pixels to degrees
double pixelDistanceToDegree(double pixelDistance){
    // printf("Convert factor = %f", 75/3464);
    double distanceInDegrees = pixelDistance * ( (double)75/3464);
    return distanceInDegrees;
}

// Calculate the distance using the formula ds = rdΘ where dΘ is angleInDegree and distance from target is r
double calcDistanceBetweenTwoImage(double angleInDegree, double r){
    // First convert angleInDegree to radian.  This is the angle opposite of the side representing distance from image1 to image2 (ds).
    double angleInRadian = (angleInDegree * M_PI) / 180;
    printf("Radian distance = %f\n", angleInRadian);
    
    // Find ds from equation.
    double ds = r * angleInRadian;
    return ds;
}

//Return the version of Opencv as NSString.
+(NSString *) openCVVersionString
{
    //Greeting g;
    //g.greet();
    //printf("%s",g.greet().c_str());
    
    return [NSString stringWithFormat:@"OpenCV Version %s", CV_VERSION];
}

@end
