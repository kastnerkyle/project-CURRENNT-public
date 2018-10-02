/******************************************************************************
 * This file is an addtional component of CURRENNT. 
 * Xin WANG
 * National Institute of Informatics, Japan
 * 2016
 *
 * This file is part of CURRENNT. 
 * Copyright (c) 2013 Johannes Bergmann, Felix Weninger, Bjoern Schuller
 * Institute for Human-Machine Communication
 * Technische Universitaet Muenchen (TUM)
 * D-80290 Munich, Germany
 *
 *
 * CURRENNT is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * CURRENNT is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with CURRENNT.  If not, see <http://www.gnu.org/licenses/>.
 *****************************************************************************/

#ifdef _MSC_VER
#   pragma warning (disable: 4244) // thrust/iterator/iterator_adaptor.h(121): warning C4244: '+=' : conversion from '__int64' to 'int', possible loss of data
#endif

#include "FFTMat.hpp"
#include "getRawPointer.cuh"
#include "safeExp.cuh"
#include <cufft.h>

#include <stdexcept>
#include <thrust/reduce.h>
#include <thrust/transform.h>
#include <thrust/random.h>
#include <thrust/transform_reduce.h>
#include <thrust/iterator/constant_iterator.h>
#include <thrust/iterator/counting_iterator.h>

typedef cufftHandle *cufftHandle_t;

#define FFT_PI_DEFINITION 3.141215
#define FFT_KLD_FLOOR_NUM 0.00001
namespace internal{
namespace {

    // cuFFT plan Handle
    //  currently, only allows 3 different FFT plans to be used
    //  this part should be modified
    
    cufftHandle_t getCuFFTHandle_fft(int fftSize, int batchSize)
    {
	static cufftHandle cufftHandle_fft = 0;
	static int fftSize_local = 0;
	static int batchSize_local = 0;
	
	static cufftHandle cufftHandle_fft2 = 0;
	static int fftSize_local2 = 0;
	static int batchSize_local2 = 0;

	static cufftHandle cufftHandle_fft3 = 0;
	static int fftSize_local3 = 0;
	static int batchSize_local3 = 0;

	if (!cufftHandle_fft){
	    fftSize_local = fftSize;
	    batchSize_local = batchSize;
	    cufftResult res = cufftPlan1d(&cufftHandle_fft, fftSize_local,
					  CUFFT_R2C, batchSize_local);
	    if (res != CUFFT_SUCCESS)
		throw std::runtime_error("Error: could not create cufft plan");
	    return &cufftHandle_fft;
	    
	}else if (fftSize_local == fftSize && batchSize_local == batchSize){
	    return &cufftHandle_fft;
	    
	}else if (!cufftHandle_fft2){
	    fftSize_local2 = fftSize;
	    batchSize_local2 = batchSize;
	    cufftResult res = cufftPlan1d(&cufftHandle_fft2, fftSize_local2,
					  CUFFT_R2C, batchSize_local2);
	    if (res != CUFFT_SUCCESS)
		throw std::runtime_error("Error: could not create cufft plan");
	    return &cufftHandle_fft2;
	    
	}else if (fftSize_local2 == fftSize && batchSize_local2 == batchSize){
	    return &cufftHandle_fft2;
	    
	}else if (!cufftHandle_fft3){
	    fftSize_local3 = fftSize;
	    batchSize_local3 = batchSize;
	    cufftResult res = cufftPlan1d(&cufftHandle_fft3, fftSize_local3,
					  CUFFT_R2C, batchSize_local3);
	    if (res != CUFFT_SUCCESS)
		throw std::runtime_error("Error: could not create cufft plan");
	    return &cufftHandle_fft3;
	    
	}else if (fftSize_local3 == fftSize && batchSize_local3 == batchSize){
	    return &cufftHandle_fft3;
	    
	}else{
	    throw std::runtime_error("Impossible");
	}
	/*
	if (!cufftHandle_fft || fftSize_local != fftSize || batchSize_local != batchSize){
	    fftSize_local = fftSize;
	    batchSize_local = batchSize;
	    cufftResult res = cufftPlan1d(&cufftHandle_fft, fftSize_local,
					  CUFFT_R2C, batchSize_local);
	    if (res != CUFFT_SUCCESS)
		throw std::runtime_error("Error: could not create cufft plan");
	    
		}*/
	    
	
    }

    cufftHandle_t getCuFFTHandle_ifft(int fftSize, int batchSize)
    {
	static cufftHandle cufftHandle_ifft = 0;
	static int fftSize_local = 0;
	static int batchSize_local = 0;
	
	static cufftHandle cufftHandle_ifft2 = 0;
	static int fftSize_local2 = 0;
	static int batchSize_local2 = 0;

	static cufftHandle cufftHandle_ifft3 = 0;
	static int fftSize_local3 = 0;
	static int batchSize_local3 = 0;

	if (!cufftHandle_ifft){
	    fftSize_local = fftSize;
	    batchSize_local = batchSize;
	    cufftResult res = cufftPlan1d(&cufftHandle_ifft, fftSize_local,
					  CUFFT_C2R, batchSize_local);
	    if (res != CUFFT_SUCCESS)
		throw std::runtime_error("Error: could not create cufft plan");
	    return &cufftHandle_ifft;
	    
	}else if (fftSize_local == fftSize && batchSize_local == batchSize){
	    return &cufftHandle_ifft;
	    
	}else if (!cufftHandle_ifft2){
	    fftSize_local2 = fftSize;
	    batchSize_local2 = batchSize;
	    cufftResult res = cufftPlan1d(&cufftHandle_ifft2, fftSize_local2,
					  CUFFT_C2R, batchSize_local2);
	    if (res != CUFFT_SUCCESS)
		throw std::runtime_error("Error: could not create cufft plan");
	    return &cufftHandle_ifft2;
	    
	}else if (fftSize_local2 == fftSize && batchSize_local2 == batchSize){
	    return &cufftHandle_ifft2;
	    
	}else if (!cufftHandle_ifft3){
	    fftSize_local3 = fftSize;
	    batchSize_local3 = batchSize;
	    cufftResult res = cufftPlan1d(&cufftHandle_ifft3, fftSize_local3,
					  CUFFT_C2R, batchSize_local3);
	    if (res != CUFFT_SUCCESS)
		throw std::runtime_error("Error: could not create cufft plan");
	    return &cufftHandle_ifft3;
	    
	}else if (fftSize_local3 == fftSize && batchSize_local3 == batchSize){
	    return &cufftHandle_ifft3;
	    
	}else{
	    throw std::runtime_error("Impossible");
	}
	

    }

    struct FrameSignal
    {
	int fftLength;   // dimension of frame (padded)
	int frameLength;
	int frameShift;
	int windowType;  // now only implemented the hann window
	
	real_t *rawData;

	__host__ __device__ void operator() (const thrust::tuple<real_t &, int> &t) const
	{
	    int frameIdx = t.get<1>() / fftLength;
	    int framePos = t.get<1>() % fftLength;

	    if (framePos < frameLength){
		// real data in each frame
		t.get<0>() = rawData[frameIdx * frameShift + framePos] *
		    0.5 * (1 - cos(2.0 * FFT_PI_DEFINITION * framePos / (frameLength - 1)));
		
	    }else{
		// Since FFT length should be >= signal length (frame length)
		//  we need zero paddings after the frame
		t.get<0>() = 0.0;
	    }
	    
	}
    };

    struct L2Distance
    {
	__host__ __device__ void operator() (const thrust::tuple<complex_t &,
					     complex_t &, complex_t &> &t) const
	{
	    // t.get<0>() source
	    // t.get<1>() target
	    // t.get<2>() buffer to store diff

	    // To save memory space, t.get<2>().x to store diff^2
	    // t.get<2>().y = [ log(Re(src)^2 + Im(src)^2) - log(Re(tar)^2 + Im(tar)^2) ]
	    t.get<2>().y = (helpers::safeLog(t.get<0>().x * t.get<0>().x +
					     t.get<0>().y * t.get<0>().y +
					     FFT_KLD_FLOOR_NUM) -
			    helpers::safeLog(t.get<1>().x * t.get<1>().x +
					     t.get<1>().y * t.get<1>().y +
					     FFT_KLD_FLOOR_NUM));
	    // t.get<2>().x = [ log(Re(src)^2 + Im(src)^2) - log(Re(tar)^2 + Im(tar)^2) ] ^ 2
	    t.get<2>().x = t.get<2>().y * t.get<2>().y;

	}
    };


    struct SpecKLD
    {
	__host__ __device__ void operator() (const thrust::tuple<complex_t &,
					     complex_t &, complex_t &> &t) const
	{
	    // t.get<0>() source
	    // t.get<1>() target
	    // t.get<2>() buffer to store diff

	    real_t source = sqrt(t.get<0>().x * t.get<0>().x + t.get<0>().y * t.get<0>().y +
				 FFT_KLD_FLOOR_NUM);
	    real_t target = sqrt(t.get<1>().x * t.get<1>().x + t.get<1>().y * t.get<1>().y +
				 FFT_KLD_FLOOR_NUM);
	    t.get<2>().x = target * helpers::safeLog(target / source) - target + source;
	    t.get<2>().y = 1.0 - target / source;

	}
    };
    
    struct L2DistanceGrad
    {
	__host__ __device__ void operator() (const thrust::tuple<complex_t &,
					     complex_t &, complex_t &> &t) const
	{
	    // t.get<0>() source
	    // t.get<1>() target
	    // t.get<2>() buffer to store diff

	    real_t spec = (t.get<0>().x * t.get<0>().x +
			   t.get<0>().y * t.get<0>().y +
			   FFT_KLD_FLOOR_NUM);
	    
	    t.get<2>().x = t.get<2>().y * t.get<0>().x / spec;
	    t.get<2>().y = t.get<2>().y * t.get<0>().y / spec;


	}
    };


    struct SpecKLDGrad
    {
	__host__ __device__ void operator() (const thrust::tuple<complex_t &,
					     complex_t &, complex_t &> &t) const
	{
	    // t.get<0>() source
	    // t.get<1>() target
	    // t.get<2>() buffer to store diff
	    real_t spec = sqrt(t.get<0>().x * t.get<0>().x +
			       t.get<0>().y * t.get<0>().y +
			       FFT_KLD_FLOOR_NUM);
	    
	    t.get<2>().x = t.get<2>().y * t.get<0>().x / spec;
	    t.get<2>().y = t.get<2>().y * t.get<0>().y / spec;

	}
    };

    
    struct getError
    {
	real_t factor;
	
	__host__ __device__ real_t operator() (const complex_t &t) const
	{
	    return (real_t)t.x / factor;
	}
    };


    struct collectGrad
    {
	int fftLength;
	int frameLength;
	int frameShift;
	int windowType;
	int frameNum;

	real_t  gradScale;
	real_t *gradData;
	
	
	__host__ __device__ void operator() (const thrust::tuple<real_t &, int> &t) const
	{
	    // starting index 0
	    // for the t-th waveform point, it is used in frames whose frame_idx staties
	    //  frame_idx * frame_shift <= t < frame_idx * frame_shift + frame_length
	    // so, frame_idx that for t would be
	    //  [ max[0, 1 + (t-frame_length)/frame_shift] , min[frame_num, t/frame_shift+1] )

	    int start_frame_idx = ((t.get<1>() >= frameLength) ?
				   (1 + (t.get<1>() - frameLength) / frameShift) :
				   0);
	    int end_frame_idx = t.get<1>() / frameShift + 1;
	    end_frame_idx = ((end_frame_idx < frameNum)?end_frame_idx:frameNum);

	    int framePos = 0;
	    t.get<0>() = 0.0;
	    for (int frameIdx = start_frame_idx; frameIdx < end_frame_idx; frameIdx++){
		framePos = t.get<1>() - frameIdx * frameShift;
		t.get<0>() += (gradData[frameIdx * fftLength + framePos]
			       * 0.5 * (1 - cos(2.0 * FFT_PI_DEFINITION * framePos /
						(frameLength - 1))));
	    }
	    t.get<0>() = t.get<0>() * gradScale;
	}
    };

    
}
}


namespace helpers {


    namespace fftTools{

	// calculate the number of frames
	int fftFrameNum(int signalLength, int frameLength, int frameShift){
	    if (signalLength < frameLength)
		return 1;
	    else
		return 1 + (signalLength - frameLength) / frameShift;
	}

	// number of fft bins (assume Hermitian symmetry)
	int fftBinsNum(int fftLength){
	    return fftLength / 2 + 1;
	}

    }

    template <typename TDevice>
    FFTMat<TDevice>::FFTMat(real_vector *rawData,
			    real_vector *framedData,
			    complex_vector *fftData,
			    int frameLength, int frameShift,
			    int windowType,  int fftLength,
			    int fftBins,
			    int batchSize,
			    int signalBufLength,
			    int signalLength,
			    int specDisType)
	
	: m_rawData         (rawData)
	, m_framedData      (framedData)
	, m_fftData         (fftData)
	, m_frameLength     (frameLength)
	, m_frameShift      (frameShift)
	, m_windowType      (windowType)
	, m_fftLength       (fftLength)
	, m_fftBins         (fftBins)
	, m_batchSize       (batchSize)
	, m_signalBufLength (signalBufLength)
	, m_signalLength    (signalLength)
	, m_specDisType     (specDisType)
	  
    {
	// m_windowType is not implemented for windows other than Hann
	// m_signalLength    (length of the current input signal)
	// m_signalBufLength (max length of all input signals)
	
	if (fftTools::fftFrameNum(m_rawData->size(), m_frameLength, m_frameShift) * m_fftLength !=
	    framedData->size() || m_rawData->size() != m_signalBufLength)
	    throw std::runtime_error("Error: mismatch size of rawData and framedData buffer");
	
	if (m_signalBufLength < m_signalLength)
	    throw std::runtime_error("Error: signal Buff length < signal length");

	thrust::fill((*m_rawData).begin() + m_signalLength,
		     (*m_rawData).end(), 0.0);

	m_validFrameNum     = fftTools::fftFrameNum(m_signalLength, m_frameLength, m_frameShift);
	m_validDataPointNum = m_validFrameNum * m_frameLength;
    }

    template <typename TDevice>
    FFTMat<TDevice>::FFTMat(real_vector *framedData, complex_vector *fftData,
			    int fftLength, int fftBins, int batchSize)
	: m_rawData      (NULL)
	, m_framedData   (framedData)
	, m_fftData      (fftData)
	, m_fftLength    (fftLength)
	, m_fftBins      (fftBins)
	, m_frameShift   (-1)
	, m_windowType   (-1)
	, m_frameLength  (-1)
	, m_signalLength (-1)
	, m_batchSize    (batchSize)
	, m_specDisType  (0)
    {
	// check?
    }
	    
    template <typename TDevice>
    FFTMat<TDevice>::~FFTMat()
    {	
    }

    template <>
    void FFTMat<Cpu>::FFT()
    {
	throw std::runtime_error("FFT using Cpu is not implemented");
    }

    template <>
    void FFTMat<Cpu>::iFFT()
    {
	throw std::runtime_error("iFFT using Cpu is not implemented");
    }

    template <typename TDevice>
    void FFTMat<TDevice>::frameSignal()
    {
	// frame and window the original signal (m_rawData)
	//  here Hann window is used
	if (m_rawData == NULL || m_framedData == NULL)
	    throw std::runtime_error("signal and framedSignal buffer not initialized");

	{{
	    internal::FrameSignal fn1;
	    fn1.fftLength   = m_fftLength;
	    fn1.frameLength = m_frameLength;
	    fn1.frameShift  = m_frameShift;
	    fn1.windowType  = m_windowType;
	    fn1.rawData     = getRawPointer(*m_rawData);
	    thrust::for_each(
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_framedData).begin(), 
					   thrust::counting_iterator<int>(0))),
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_framedData).end(),  
					   thrust::counting_iterator<int>(0) +
					   m_framedData->size())),
		fn1);
	}}
	    
    }

    
    template <>
    void FFTMat<Gpu>::FFT()
    {
	// conduct FFT
	cufftResult res;
	res = cufftExecR2C((*internal::getCuFFTHandle_fft(m_fftLength, m_batchSize)),
			   (cufftReal *)getRawPointer(*m_framedData),
			   (cufftComplex *)getRawPointer(*m_fftData));
	if (res != CUFFT_SUCCESS)
	    throw std::runtime_error("Error: could not create cufft plan");

    }

    template <>
    void FFTMat<Gpu>::iFFT()
    {
	// conduct iFFT
	cufftResult res;
	res = cufftExecC2R((*internal::getCuFFTHandle_ifft(m_fftLength, m_batchSize)),
			   (cufftComplex *)getRawPointer(*m_fftData),
			   (cufftReal *)getRawPointer(*m_framedData));
	if (res != CUFFT_SUCCESS)
	    throw std::runtime_error("Error: could not create cufft plan");
	
    }

    template <typename TDevice>
    real_t FFTMat<TDevice>::FFTL2Distance(FFTMat<TDevice> &target, FFTMat<TDevice> &diff)
    {
	// calculate the spectral-distrince
	if (this->m_fftData->size() != target.m_fftData->size())
	    throw std::runtime_error("FFTL2Distance error: input fft data unequal size");
	
	if (m_specDisType == FFTMAT_SPECTYPE_KLD){
	    {
		internal::SpecKLD fn1;
		thrust::for_each(
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_fftData).begin(),
					   (*(target.m_fftData)).begin(),
					   (*(diff.m_fftData)).begin())),
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_fftData).end(),
					   (*(target.m_fftData)).end(),
					   (*(diff.m_fftData)).end())),
		fn1);
	    }
	}else{
	    {
		internal::L2Distance fn1;
		thrust::for_each(
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_fftData).begin(),
					   (*(target.m_fftData)).begin(),
					   (*(diff.m_fftData)).begin())),
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_fftData).end(),
					   (*(target.m_fftData)).end(),
					   (*(diff.m_fftData)).end())),
		fn1);
	    }
	}

	// sum the spectral-distance
	real_t distance = 0.0;
	{{
		internal::getError fn2;
		//fn2.factor = 1.0/this->m_fftData->size();
		fn2.factor = fftTools::fftBinsNum(m_fftLength) * m_validFrameNum;
		distance = thrust::transform_reduce((*(diff.m_fftData)).begin(),
						    (*(diff.m_fftData)).begin() + (int)fn2.factor,
						    fn2,
						    (real_t)0,
						    thrust::plus<real_t>());
	}}
	return distance;
    }

    template <typename TDevice>
    void FFTMat<TDevice>::prepareGrad(FFTMat<TDevice> &source, FFTMat<TDevice> &target)
    {

	// calculate the gradient at each frequency bin and each time step
	if (m_specDisType == FFTMAT_SPECTYPE_KLD){
	    {
		internal::SpecKLDGrad fn1;
		thrust::for_each(
		thrust::make_zip_iterator(
			thrust::make_tuple((*(source.m_fftData)).begin(),
					   (*(target.m_fftData)).begin(),
					   (*m_fftData).begin())),
		thrust::make_zip_iterator(
			thrust::make_tuple((*(source.m_fftData)).end(),
					   (*(target.m_fftData)).end(),
					   (*m_fftData).end())),
		fn1);
	    }
	}else{
	      {
		  internal::L2DistanceGrad fn1;
		  thrust::for_each(
		thrust::make_zip_iterator(
			thrust::make_tuple((*(source.m_fftData)).begin(),
					   (*(target.m_fftData)).begin(),
					   (*m_fftData).begin())),
		thrust::make_zip_iterator(
			thrust::make_tuple((*(source.m_fftData)).end(),
					   (*(target.m_fftData)).end(),
					   (*m_fftData).end())),
		fn1);
	      }
	}
	
    }

    template <typename TDevice>
    void FFTMat<TDevice>::collectGrad(real_t gradScaleFactor)
    {

	// set the gradients of dummy time point to zero
	thrust::fill((*m_framedData).begin() + m_validDataPointNum, (*m_framedData).end(), 0.0);
	    
	// calculate the gradient w.r.t original signal by accumulating
	// gradients w.r.t framed signals
	{{
	    internal::collectGrad fn1;
	    fn1.fftLength   = m_fftLength;
	    fn1.frameLength = m_frameLength;
	    fn1.frameShift  = m_frameShift;
	    fn1.frameNum    = m_framedData->size() / m_fftLength;
	    fn1.windowType  = m_windowType;
	    fn1.gradData    = getRawPointer(*m_framedData);
	    fn1.gradScale   = gradScaleFactor / m_validDataPointNum;
		
	    thrust::for_each(
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_rawData).begin(), 
					   thrust::counting_iterator<int>(0))),
		thrust::make_zip_iterator(
			thrust::make_tuple((*m_rawData).end(),  
					   thrust::counting_iterator<int>(0) +
					   m_rawData->size())),
		fn1);

	}}
    }
    
    template class FFTMat<Cpu>;
    template class FFTMat<Gpu>;
}
